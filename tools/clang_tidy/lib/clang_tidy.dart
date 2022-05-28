// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show jsonDecode;
import 'dart:io' as io show Directory, File, stdout, stderr;

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:process_runner/process_runner.dart';

import 'src/command.dart';
import 'src/git_repo.dart';
import 'src/options.dart';

const String _linterOutputHeader = '''
┌──────────────────────────┐
│ Engine Clang Tidy Linter │
└──────────────────────────┘
The following errors have been reported by the Engine Clang Tidy Linter.  For
more information on addressing these issues please see:
https://github.com/flutter/flutter/wiki/Engine-Clang-Tidy-Linter
''';

class _ComputeJobsResult {
  _ComputeJobsResult(this.jobs, this.sawMalformed);

  final List<WorkerJob> jobs;
  final bool sawMalformed;
}

/// A class that runs clang-tidy on all or only the changed files in a git
/// repo.
class ClangTidy {
  /// Given the path to the build commands for a repo and its root, builds
  /// an instance of [ClangTidy].
  ///
  /// `buildCommandsPath` is the path to the build_commands.json file.
  /// `repoPath` is the path to the Engine repo.
  /// `checksArg` are specific checks for clang-tidy to do.
  /// `lintAll` when true indicates that all files should be linted.
  /// `outSink` when provided is the destination for normal log messages, which
  /// will otherwise go to stdout.
  /// `errSink` when provided is the destination for error messages, which
  /// will otherwise go to stderr.
  ClangTidy({
    required io.File buildCommandsPath,
    required io.Directory repoPath,
    String checksArg = '',
    bool lintAll = false,
    StringSink? outSink,
    StringSink? errSink,
  }) :
    options = Options(
      buildCommandsPath: buildCommandsPath,
      repoPath: repoPath,
      checksArg: checksArg,
      lintAll: lintAll,
      errSink: errSink,
    ),
    _outSink = outSink ?? io.stdout,
    _errSink = errSink ?? io.stderr;

  /// Builds an instance of [ClangTidy] from a command line.
  ClangTidy.fromCommandLine(
    List<String> args, {
    StringSink? outSink,
    StringSink? errSink,
  }) :
    options = Options.fromCommandLine(args, errSink: errSink),
    _outSink = outSink ?? io.stdout,
    _errSink = errSink ?? io.stderr;

  /// The [Options] that specify how this [ClangTidy] operates.
  final Options options;
  final StringSink _outSink;
  final StringSink _errSink;

  /// Runs clang-tidy on the repo as specified by the [Options].
  Future<int> run() async {
    if (options.help) {
      options.printUsage();
      return 0;
    }

    if (options.errorMessage != null) {
      options.printUsage(message: options.errorMessage);
      return 1;
    }

    _outSink.writeln(_linterOutputHeader);

    final List<io.File> changedFiles = await computeChangedFiles();

    if (options.verbose) {
      _outSink.writeln('Checking lint in repo at ${options.repoPath.path}.');
      if (options.checksArg.isNotEmpty) {
        _outSink.writeln('Checking for specific checks: ${options.checks}.');
      }
      final int changedFilesCount = changedFiles.length;
      if (options.lintAll) {
        _outSink.writeln('Checking all $changedFilesCount files the repo dir.');
      } else {
        _outSink.writeln(
          'Dectected $changedFilesCount files that have changed',
        );
      }
    }

    final List<dynamic> buildCommandsData = jsonDecode(
      options.buildCommandsPath.readAsStringSync(),
    ) as List<dynamic>;
    final List<Command> changedFileBuildCommands = getLintCommandsForChangedFiles(
      buildCommandsData,
      changedFiles,
    );

    if (changedFileBuildCommands.isEmpty) {
      _outSink.writeln(
        'No changed files that have build commands associated with them were '
        'found.',
      );
      return 0;
    }

    if (options.verbose) {
      _outSink.writeln(
        'Found ${changedFileBuildCommands.length} files that have build '
        'commands associated with them and can be lint checked.',
      );
    }

    final _ComputeJobsResult computeJobsResult = await _computeJobs(
      changedFileBuildCommands,
      options.repoPath,
      options.checks,
    );
    final int computeResult = computeJobsResult.sawMalformed ? 1 : 0;
    final List<WorkerJob> jobs = computeJobsResult.jobs;

    final int runResult = await _runJobs(jobs);
    _outSink.writeln('\n');
    if (computeResult + runResult == 0) {
      _outSink.writeln('No lint problems found.');
    } else {
      _errSink.writeln('Lint problems found.');
    }

    return computeResult + runResult > 0 ? 1 : 0;
  }

  /// The files with local modifications or all the files if `lintAll` was
  /// specified.
  @visibleForTesting
  Future<List<io.File>> computeChangedFiles() async {
    if (options.lintAll) {
      return options.repoPath
        .listSync(recursive: true)
        .whereType<io.File>()
        .toList();
    }
    return GitRepo(options.repoPath).changedFiles;
  }

  /// Given a build commands json file, and the files with local changes,
  /// compute the lint commands to run.
  @visibleForTesting
  List<Command> getLintCommandsForChangedFiles(
    List<dynamic> buildCommandsData,
    List<io.File> changedFiles,
  ) {
    final List<Command> buildCommands = <Command>[
      for (final dynamic c in buildCommandsData)
        Command.fromMap(c as Map<String, dynamic>),
    ];

    return <Command>[
      for (final Command c in buildCommands)
        if (c.containsAny(changedFiles))
          c,
    ];
  }

  Future<_ComputeJobsResult> _computeJobs(
    List<Command> commands,
    io.Directory repoPath,
    String checks,
  ) async {
    bool sawMalformed = false;
    final List<WorkerJob> jobs = <WorkerJob>[];
    for (final Command command in commands) {
      final String relativePath = path.relative(
        command.filePath,
        from: repoPath.parent.path,
      );
      final LintAction action = await command.lintAction;
      switch (action) {
        case LintAction.skipNoLint:
          _outSink.writeln('🔷 ignoring $relativePath (FLUTTER_NOLINT)');
          break;
        case LintAction.failMalformedNoLint:
          _errSink.writeln('❌ malformed opt-out $relativePath');
          _errSink.writeln(
            '   Required format: // FLUTTER_NOLINT: $issueUrlPrefix/ISSUE_ID',
          );
          sawMalformed = true;
          break;
        case LintAction.lint:
          _outSink.writeln('🔶 linting $relativePath');
          jobs.add(command.createLintJob(checks));
          break;
        case LintAction.skipThirdParty:
          _outSink.writeln('🔷 ignoring $relativePath (third_party)');
          break;
      }
    }
    return _ComputeJobsResult(jobs, sawMalformed);
  }

  Future<int> _runJobs(List<WorkerJob> jobs) async {
    int result = 0;
    final ProcessPool pool = ProcessPool();
    await for (final WorkerJob job in pool.startWorkers(jobs)) {
      if (job.result.exitCode == 0) {
        continue;
      }
      if (job.exception != null) {
        _errSink.writeln(
          '\n❗ A clang-tidy job failed to run, aborting:\n${job.exception}',
        );
        result = 1;
        break;
      } else {
        _errSink.writeln('❌ Failures for ${job.name}:');
        _errSink.writeln(job.result.stdout);
      }
      result = 1;
    }
    return result;
  }
}



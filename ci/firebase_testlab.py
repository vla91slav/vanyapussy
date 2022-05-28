#!/usr/bin/env python3
#
# Copyright 2013 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import argparse
import glob
import re
import os
import subprocess
import sys

script_dir = os.path.dirname(os.path.realpath(__file__))
buildroot_dir = os.path.abspath(os.path.join(script_dir, '..', '..'))
out_dir = os.path.join(buildroot_dir, 'out')
bucket = 'gs://flutter_firebase_testlab'
error_re = re.compile(r'[EF]/flutter.+')


def RunFirebaseTest(apk, results_dir):
  # game-loop tests are meant for OpenGL apps.
  # This type of test will give the application a handle to a file, and
  # we'll write the timeline JSON to that file.
  # See https://firebase.google.com/docs/test-lab/android/game-loop
  # Pixel 4. As of this commit, this is a highly available device in FTL.
  process = subprocess.Popen(
    [
      'gcloud',
      '--project', 'flutter-infra',
      'firebase', 'test', 'android', 'run',
      '--type', 'game-loop',
      '--app', apk,
      '--timeout', '2m',
      '--results-bucket', bucket,
      '--results-dir', results_dir,
      '--device', 'model=flame,version=29',
    ],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True,
  )
  return process


def CheckLogcat(results_dir):
  logcat = subprocess.check_output([
      'gsutil', 'cat', '%s/%s/*/logcat' % (bucket, results_dir)
  ])
  if not logcat:
    sys.exit(1)

  logcat_matches = error_re.findall(logcat)
  if logcat_matches:
    print('Errors in logcat:')
    print(logcat_matches)
    sys.exit(1)


def CheckTimeline(results_dir):
  du = subprocess.check_output([
      'gsutil', 'du',
      '%s/%s/*/game_loop_results/results_scenario_0.json' % (bucket, results_dir)
  ]).strip()
  if du == '0':
    print('Failed to produce a timeline.')
    sys.exit(1)


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('--variant', dest='variant', action='store',
      default='android_profile_arm64', help='The engine variant to run tests for.')
  parser.add_argument('--build-id',
      default=os.environ.get('SWARMING_TASK_ID', 'local_test'),
      help='A unique build identifier for this test. Used to sort results in the GCS bucket.')

  args = parser.parse_args()

  apks_dir = os.path.join(out_dir, args.variant, 'firebase_apks')
  apks = glob.glob('%s/*.apk' % apks_dir)

  if not apks:
    print('No APKs found at %s' % apks_dir)
    return 1

  git_revision = subprocess.check_output(
      ['git', 'rev-parse', 'HEAD'], cwd=script_dir).strip()

  results = []
  for apk in apks:
    results_dir = '%s/%s/%s' % (os.path.basename(apk), git_revision, args.build_id)
    process = RunFirebaseTest(apk, results_dir)
    results.append((results_dir, process))

  for results_dir, process in results:
    for line in iter(process.stdout.readline, ""):
      print(line.strip())
    return_code = process.wait()
    if return_code != 0:
      print('Firebase test failed ' + returncode)
      sys.exit(process.returncode)

    print('Checking logcat for %s' % results_dir)
    CheckLogcat(results_dir)
    # scenario_app produces a timeline, but the android image test does not.
    if 'scenario' in apk:
      print('Checking timeline for %s' % results_dir)
      CheckTimeline(results_dir)

  return 0


if __name__ == '__main__':
  sys.exit(main())

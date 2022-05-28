// Copyright 2021 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// FlutterTesterOptions=--disallow-insecure-connections

import 'dart:async';
import 'dart:io';

import 'package:litetest/litetest.dart';

/// Asserts that `callback` throws an exception of type `T`.
Future<void> asyncExpectThrows<T>(Function callback) async {
  bool threw = false;
  try {
    await callback();
  } catch (e) {
    expect(e is T, true);
    threw = true;
  }
  expect(threw, true);
}

Future<String> getLocalHostIP() async {
  final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false, type: InternetAddressType.IPv4);
  return interfaces.first.addresses.first.address;
}

Future<void> bindServerAndTest(String serverHost,
    Future<void> Function(HttpClient client, Uri uri) testCode) async {
  final HttpClient httpClient = HttpClient();
  final HttpServer server = await HttpServer.bind(serverHost, 0);
  final Uri uri = Uri(scheme: 'http', host: serverHost, port: server.port);
  try {
    await testCode(httpClient, uri);
  } finally {
    httpClient.close(force: true);
    await server.close();
  }
}

/// Answers the question whether this computer supports binding to IPv6 addresses.
Future<bool> _supportsIPv6() async {
  try {
    final ServerSocket socket = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
    await socket.close();
    return true;
  } on SocketException catch (_) {
    return false;
  }
}

void main() {
  test('testWithHostname', () async {
    await bindServerAndTest(await getLocalHostIP(), (HttpClient httpClient, Uri httpUri) async {
      asyncExpectThrows<UnsupportedError>(
          () async =>  httpClient.getUrl(httpUri));
      asyncExpectThrows<UnsupportedError>(
          () async => runZoned(() => httpClient.getUrl(httpUri),
            zoneValues: <dynamic, dynamic>{#flutter.io.allow_http: 'foo'}));
      asyncExpectThrows<UnsupportedError>(
          () async => runZoned(() => httpClient.getUrl(httpUri),
            zoneValues: <dynamic, dynamic>{#flutter.io.allow_http: false}));
      await runZoned(() => httpClient.getUrl(httpUri),
        zoneValues: <dynamic, dynamic>{#flutter.io.allow_http: true});
    });
  });

  test('testWithLoopback', () async {
    await bindServerAndTest('127.0.0.1', (HttpClient httpClient, Uri uri) async {
      await httpClient.getUrl(Uri.parse('http://localhost:${uri.port}'));
      await httpClient.getUrl(Uri.parse('http://127.0.0.1:${uri.port}'));
    });
  });

  test('testWithIPV6', () async {
    if (await _supportsIPv6()) {
      await bindServerAndTest('::1', (HttpClient httpClient, Uri uri) async {
        await httpClient.getUrl(uri);
      });
    }
  });
}

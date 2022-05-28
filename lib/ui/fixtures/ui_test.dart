// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

void main() {}

/// Mutiple tests use this to signal to the C++ side that they are ready for
/// validation.
void _finish() native 'Finish';

@pragma('vm:entry-point')
void validateSceneBuilderAndScene() {
  final SceneBuilder builder = SceneBuilder();
  builder.pushOffset(10, 10);
  _validateBuilderHasLayers(builder);
  final Scene scene = builder.build();
  _validateBuilderHasNoLayers();
  _captureScene(scene);
  scene.dispose();
  _validateSceneHasNoLayers();
}
_validateBuilderHasLayers(SceneBuilder builder) native 'ValidateBuilderHasLayers';
_validateBuilderHasNoLayers() native 'ValidateBuilderHasNoLayers';
_captureScene(Scene scene) native 'CaptureScene';
_validateSceneHasNoLayers() native 'ValidateSceneHasNoLayers';

@pragma('vm:entry-point')
void validateEngineLayerDispose() {
  final SceneBuilder builder = SceneBuilder();
  final EngineLayer layer = builder.pushOffset(10, 10);
  _captureRootLayer(builder);
  final Scene scene = builder.build();
  scene.dispose();
  _validateLayerTreeCounts();
  layer.dispose();
  _validateEngineLayerDispose();
}
_captureRootLayer(SceneBuilder sceneBuilder) native 'CaptureRootLayer';
_validateLayerTreeCounts() native 'ValidateLayerTreeCounts';
_validateEngineLayerDispose() native 'ValidateEngineLayerDispose';

@pragma('vm:entry-point')
Future<void> createSingleFrameCodec() async {
  final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(Uint8List.fromList(List<int>.filled(4, 100)));
  final ImageDescriptor descriptor = ImageDescriptor.raw(
    buffer,
    width: 1,
    height: 1,
    pixelFormat: PixelFormat.rgba8888,
  );
  final Codec codec = await descriptor.instantiateCodec();
  _validateCodec(codec);
  final FrameInfo info = await codec.getNextFrame();
  info.image.dispose();
  _validateCodec(codec);
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  assert(buffer.debugDisposed);
  _finish();
}
void _validateCodec(Codec codec) native 'ValidateCodec';

@pragma('vm:entry-point')
void createVertices() {
  const int uint16max = 65535;

  final Int32List colors = Int32List(uint16max);
  final Float32List coords = Float32List(uint16max * 2);
  final Uint16List indices = Uint16List(uint16max);
  final Float32List positions = Float32List(uint16max * 2);
  colors[0] = const Color(0xFFFF0000).value;
  colors[1] = const Color(0xFF00FF00).value;
  colors[2] = const Color(0xFF0000FF).value;
  colors[3] = const Color(0xFF00FFFF).value;
  indices[1] = indices[3] = 1;
  indices[2] = indices[5] = 3;
  indices[4] = 2;
  positions[2] = positions[4] = positions[5] = positions[7] = 250.0;

  final Vertices vertices = Vertices.raw(
    VertexMode.triangles,
    positions,
    textureCoordinates: coords,
    colors: colors,
    indices: indices,
  );
  _validateVertices(vertices);
}
void _validateVertices(Vertices vertices) native 'ValidateVertices';

@pragma('vm:entry-point')
void sendSemanticsUpdate() {
  final SemanticsUpdateBuilder builder = SemanticsUpdateBuilder();
  final String label = "label";
  final List<StringAttribute> labelAttributes = <StringAttribute> [
    SpellOutStringAttribute(range: TextRange(start: 1, end: 2)),
  ];

  final String value = "value";
  final List<StringAttribute> valueAttributes = <StringAttribute> [
    SpellOutStringAttribute(range: TextRange(start: 2, end: 3)),
  ];

  final String increasedValue = "increasedValue";
  final List<StringAttribute> increasedValueAttributes = <StringAttribute> [
    SpellOutStringAttribute(range: TextRange(start: 4, end: 5)),
  ];

  final String decreasedValue = "decreasedValue";
  final List<StringAttribute> decreasedValueAttributes = <StringAttribute> [
    SpellOutStringAttribute(range: TextRange(start: 5, end: 6)),
  ];

  final String hint = "hint";
  final List<StringAttribute> hintAttributes = <StringAttribute> [
    LocaleStringAttribute(
      locale: Locale('en', 'MX'), range: TextRange(start: 0, end: 1),
    ),
  ];

  final Float64List transform = Float64List(16);
  final Int32List childrenInTraversalOrder = Int32List(0);
  final Int32List childrenInHitTestOrder = Int32List(0);
  final Int32List additionalActions = Int32List(0);
  transform[0] = 1;
  transform[1] = 0;
  transform[2] = 0;
  transform[3] = 0;

  transform[4] = 0;
  transform[5] = 1;
  transform[6] = 0;
  transform[7] = 0;

  transform[8] = 0;
  transform[9] = 0;
  transform[10] = 1;
  transform[11] = 0;

  transform[12] = 0;
  transform[13] = 0;
  transform[14] = 0;
  transform[15] = 0;
  builder.updateNode(
    id: 0,
    flags: 0,
    actions: 0,
    maxValueLength: 0,
    currentValueLength: 0,
    textSelectionBase: -1,
    textSelectionExtent: -1,
    platformViewId: -1,
    scrollChildren: 0,
    scrollIndex: 0,
    scrollPosition: 0,
    scrollExtentMax: 0,
    scrollExtentMin: 0,
    rect: Rect.fromLTRB(0, 0, 10, 10),
    elevation: 0,
    thickness: 0,
    label: label,
    labelAttributes: labelAttributes,
    value: value,
    valueAttributes: valueAttributes,
    increasedValue: increasedValue,
    increasedValueAttributes: increasedValueAttributes,
    decreasedValue: decreasedValue,
    decreasedValueAttributes: decreasedValueAttributes,
    hint: hint,
    hintAttributes: hintAttributes,
    textDirection: TextDirection.ltr,
    transform: transform,
    childrenInTraversalOrder: childrenInTraversalOrder,
    childrenInHitTestOrder: childrenInHitTestOrder,
    additionalActions: additionalActions
  );
  _semanticsUpdate(builder.build());
}

void _semanticsUpdate(SemanticsUpdate update) native 'SemanticsUpdate';

@pragma('vm:entry-point')
void createPath() {
  final Path path = Path()..lineTo(10, 10);
  _validatePath(path);
  // Arbitrarily hold a reference to the path to make sure it does not get
  // garbage collected.
  Future<void>.delayed(const Duration(days: 100)).then((_) {
    path.lineTo(100, 100);
  });
}
void _validatePath(Path path) native 'ValidatePath';

@pragma('vm:entry-point')
void frameCallback(FrameInfo info) {
  print('called back');
}

@pragma('vm:entry-point')
void messageCallback(dynamic data) {}

@pragma('vm:entry-point')
void validateConfiguration() native 'ValidateConfiguration';


// Draw a circle on a Canvas that has a PictureRecorder. Take the image from
// the PictureRecorder, and encode it as png. Check that the png data is
// backed by an external Uint8List.
@pragma('vm:entry-point')
Future<void> encodeImageProducesExternalUint8List() async {
  final PictureRecorder pictureRecorder = PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()
    ..color = Color.fromRGBO(255, 255, 255, 1.0)
    ..style = PaintingStyle.fill;
  final Offset c = Offset(50.0, 50.0);
  canvas.drawCircle(c, 25.0, paint);
  final Picture picture = pictureRecorder.endRecording();
  final Image image = await picture.toImage(100, 100);
  _encodeImage(image, ImageByteFormat.png.index, (Uint8List result) {
    // The buffer should be non-null and writable.
    result[0] = 0;
    // The buffer should be external typed data.
    _validateExternal(result);
  });
}
void _encodeImage(Image i, int format, void Function(Uint8List result))
  native 'EncodeImage';
void _validateExternal(Uint8List result) native 'ValidateExternal';

@pragma('vm:entry-point')
Future<void> pumpImage() async {
  const int width = 60;
  const int height = 60;
  final Completer<Image> completer = Completer<Image>();
  decodeImageFromPixels(
    Uint8List.fromList(List<int>.filled(width * height * 4, 0xFF)),
    width,
    height,
    PixelFormat.rgba8888,
    (Image image) => completer.complete(image),
  );
  final Image image = await completer.future;
  late Picture picture;
  late OffsetEngineLayer layer;

  void renderBlank(Duration duration) {
    image.dispose();
    picture.dispose();
    layer.dispose();

    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawPaint(Paint());
    picture = recorder.endRecording();
    final SceneBuilder builder = SceneBuilder();
    layer = builder.pushOffset(0, 0);
    builder.addPicture(Offset.zero, picture);

    final Scene scene = builder.build();
    window.render(scene);
    scene.dispose();

    _finish();
  }

  void renderImage(Duration duration) {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    picture = recorder.endRecording();

    final SceneBuilder builder = SceneBuilder();
    layer = builder.pushOffset(0, 0);
    builder.addPicture(Offset.zero, picture);

    _captureImageAndPicture(image, picture);

    final Scene scene = builder.build();
    window.render(scene);
    scene.dispose();

    window.onBeginFrame = renderBlank;
    window.scheduleFrame();
  }

  window.onBeginFrame = renderImage;
  window.scheduleFrame();
}
void _captureImageAndPicture(Image image, Picture picture) native 'CaptureImageAndPicture';

@pragma('vm:entry-point')
void hooksTests() {
  void test(String name, VoidCallback testFunction) {
    try {
      testFunction();
    } catch (e) {
      print('Test "$name" failed!');
      rethrow;
    }
  }

  void expectEquals(Object? value, Object? expected) {
    if (value != expected) {
      throw 'Expected $value to be $expected.';
    }
  }

  void expectIdentical(Zone originalZone, Zone callbackZone) {
    if (!identical(callbackZone, originalZone)) {
      throw 'Callback called in wrong zone.';
    }
  }

  void expectNotEquals(Object? value, Object? expected) {
    if (value == expected) {
      throw 'Expected $value to not be $expected.';
    }
  }

  test('onMetricsChanged preserves callback zone', () {
    late Zone originalZone;
    late Zone callbackZone;
    late double devicePixelRatio;

    runZoned(() {
      originalZone = Zone.current;
      window.onMetricsChanged = () {
        callbackZone = Zone.current;
        devicePixelRatio = window.devicePixelRatio;
      };
    });

    window.onMetricsChanged!();
    _callHook(
      '_updateWindowMetrics',
      17,
      0, // window Id
      0.1234, // device pixel ratio
      0.0,    // width
      0.0,    // height
      0.0,    // padding top
      0.0,    // padding right
      0.0,    // padding bottom
      0.0,    // padding left
      0.0,    // inset top
      0.0,    // inset right
      0.0,    // inset bottom
      0.0,    // inset left
      0.0,    // system gesture inset top
      0.0,    // system gesture inset right
      0.0,    // system gesture inset bottom
      0.0,    // system gesture inset left,
      22.0,   // physicalTouchSlop
    );

    expectIdentical(originalZone, callbackZone);
    if (devicePixelRatio != 0.1234) {
      throw 'Expected devicePixelRatio to be 0.1234 but got $devicePixelRatio.';
    }
  });

  test('updateUserSettings can handle an empty object', () {
    _callHook('_updateUserSettingsData', 1, '{}');
  });

  test('PlatformDispatcher.locale returns unknown locale when locales is set to empty list', () {
    late Locale locale;
    int callCount = 0;
    runZoned(() {
      window.onLocaleChanged = () {
        locale = PlatformDispatcher.instance.locale;
        callCount += 1;
      };
    });

    const Locale fakeLocale = Locale.fromSubtags(languageCode: '1', countryCode: '2', scriptCode: '3');
    _callHook('_updateLocales', 1, <String>[fakeLocale.languageCode, fakeLocale.countryCode!, fakeLocale.scriptCode!, '']);
    if (callCount != 1) {
      throw 'Expected 1 call, have $callCount';
    }
    if (locale != fakeLocale) {
      throw 'Expected $locale to match $fakeLocale';
    }
    _callHook('_updateLocales', 1, <String>[]);
    if (callCount != 2) {
      throw 'Expected 2 calls, have $callCount';
    }

    if (locale != const Locale.fromSubtags()) {
      throw '$locale did not equal ${Locale.fromSubtags()}';
    }
    if (locale.languageCode != 'und') {
      throw '${locale.languageCode} did not equal "und"';
    }
  });

  test('Window padding/insets/viewPadding/systemGestureInsets', () {
    _callHook(
      '_updateWindowMetrics',
      17,
      0, // window Id
      1.0, // devicePixelRatio
      800.0, // width
      600.0, // height
      50.0, // paddingTop
      0.0, // paddingRight
      40.0, // paddingBottom
      0.0, // paddingLeft
      0.0, // insetTop
      0.0, // insetRight
      0.0, // insetBottom
      0.0, // insetLeft
      0.0, // systemGestureInsetTop
      0.0, // systemGestureInsetRight
      0.0, // systemGestureInsetBottom
      0.0, // systemGestureInsetLeft
      22.0, // physicalTouchSlop
    );

    expectEquals(window.viewInsets.bottom, 0.0);
    expectEquals(window.viewPadding.bottom, 40.0);
    expectEquals(window.padding.bottom, 40.0);
    expectEquals(window.systemGestureInsets.bottom, 0.0);

    _callHook(
      '_updateWindowMetrics',
      17,
      0, // window Id
      1.0, // devicePixelRatio
      800.0, // width
      600.0, // height
      50.0, // paddingTop
      0.0, // paddingRight
      40.0, // paddingBottom
      0.0, // paddingLeft
      0.0, // insetTop
      0.0, // insetRight
      400.0, // insetBottom
      0.0, // insetLeft
      0.0, // systemGestureInsetTop
      0.0, // systemGestureInsetRight
      44.0, // systemGestureInsetBottom
      0.0, // systemGestureInsetLeft
      22.0, // physicalTouchSlop
    );

    expectEquals(window.viewInsets.bottom, 400.0);
    expectEquals(window.viewPadding.bottom, 40.0);
    expectEquals(window.padding.bottom, 0.0);
    expectEquals(window.systemGestureInsets.bottom, 44.0);
  });

   test('Window physical touch slop', () {
    _callHook(
      '_updateWindowMetrics',
      17,
      0, // window Id
      1.0, // devicePixelRatio
      800.0, // width
      600.0, // height
      50.0, // paddingTop
      0.0, // paddingRight
      40.0, // paddingBottom
      0.0, // paddingLeft
      0.0, // insetTop
      0.0, // insetRight
      0.0, // insetBottom
      0.0, // insetLeft
      0.0, // systemGestureInsetTop
      0.0, // systemGestureInsetRight
      0.0, // systemGestureInsetBottom
      0.0, // systemGestureInsetLeft
      11.0, // physicalTouchSlop
    );

    expectEquals(window.viewConfiguration.gestureSettings,
      GestureSettings(physicalTouchSlop: 11.0));

    _callHook(
      '_updateWindowMetrics',
      17,
      0, // window Id
      1.0, // devicePixelRatio
      800.0, // width
      600.0, // height
      50.0, // paddingTop
      0.0, // paddingRight
      40.0, // paddingBottom
      0.0, // paddingLeft
      0.0, // insetTop
      0.0, // insetRight
      400.0, // insetBottom
      0.0, // insetLeft
      0.0, // systemGestureInsetTop
      0.0, // systemGestureInsetRight
      44.0, // systemGestureInsetBottom
      0.0, // systemGestureInsetLeft
      -1.0, // physicalTouchSlop
    );

    expectEquals(window.viewConfiguration.gestureSettings,
      GestureSettings(physicalTouchSlop: null));

    _callHook(
      '_updateWindowMetrics',
      17,
      0, // window Id
      1.0, // devicePixelRatio
      800.0, // width
      600.0, // height
      50.0, // paddingTop
      0.0, // paddingRight
      40.0, // paddingBottom
      0.0, // paddingLeft
      0.0, // insetTop
      0.0, // insetRight
      400.0, // insetBottom
      0.0, // insetLeft
      0.0, // systemGestureInsetTop
      0.0, // systemGestureInsetRight
      44.0, // systemGestureInsetBottom
      0.0, // systemGestureInsetLeft
      22.0, // physicalTouchSlop
    );

    expectEquals(window.viewConfiguration.gestureSettings,
      GestureSettings(physicalTouchSlop: 22.0));
  });

  test('onLocaleChanged preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    Locale? locale;

    runZoned(() {
      innerZone = Zone.current;
      window.onLocaleChanged = () {
        runZone = Zone.current;
        locale = window.locale;
      };
    });

    _callHook('_updateLocales', 1, <String>['en', 'US', '', '']);
    expectIdentical(runZone, innerZone);
    expectEquals(locale, const Locale('en', 'US'));
  });

  test('onBeginFrame preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    late Duration start;

    runZoned(() {
      innerZone = Zone.current;
      window.onBeginFrame = (Duration value) {
        runZone = Zone.current;
        start = value;
      };
    });

    _callHook('_beginFrame', 2, 1234, 1);
    expectIdentical(runZone, innerZone);
    expectEquals(start, const Duration(microseconds: 1234));
  });

  test('onDrawFrame preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;

    runZoned(() {
      innerZone = Zone.current;
      window.onDrawFrame = () {
        runZone = Zone.current;
      };
    });

    _callHook('_drawFrame');
    expectIdentical(runZone, innerZone);
  });

  test('onReportTimings preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;

    runZoned(() {
      innerZone = Zone.current;
      window.onReportTimings = (List<FrameTiming> timings) {
        runZone = Zone.current;
      };
    });

    _callHook('_reportTimings', 1, <int>[]);
    expectIdentical(runZone, innerZone);
  });

  test('onPointerDataPacket preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    late PointerDataPacket data;

    runZoned(() {
      innerZone = Zone.current;
      window.onPointerDataPacket = (PointerDataPacket value) {
        runZone = Zone.current;
        data = value;
      };
    });

    final ByteData testData = ByteData.view(Uint8List(0).buffer);
    _callHook('_dispatchPointerDataPacket', 1, testData);
    expectIdentical(runZone, innerZone);
    expectEquals(data.data.length, 0);
  });

  test('onSemanticsEnabledChanged preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    late bool enabled;

    runZoned(() {
      innerZone = Zone.current;
      window.onSemanticsEnabledChanged = () {
        runZone = Zone.current;
        enabled = window.semanticsEnabled;
      };
    });

    final bool newValue = !window.semanticsEnabled; // needed?
    _callHook('_updateSemanticsEnabled', 1, newValue);
    expectIdentical(runZone, innerZone);
    expectEquals(enabled, newValue);
  });

  test('onSemanticsAction preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    late int id;
    late int action;

    runZoned(() {
      innerZone = Zone.current;
      window.onSemanticsAction = (int i, SemanticsAction a, ByteData? _) {
        runZone = Zone.current;
        action = a.index;
        id = i;
      };
    });

    _callHook('_dispatchSemanticsAction', 3, 1234, 4, null);
    expectIdentical(runZone, innerZone);
    expectEquals(id, 1234);
    expectEquals(action, 4);
  });

  test('onPlatformMessage preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    late String name;

    runZoned(() {
      innerZone = Zone.current;
      window.onPlatformMessage = (String value, _, __) {
        runZone = Zone.current;
        name = value;
      };
    });

    _callHook('_dispatchPlatformMessage', 3, 'testName', null, 123456789);
    expectIdentical(runZone, innerZone);
    expectEquals(name, 'testName');
  });

  test('onTextScaleFactorChanged preserves callback zone', () {
    late Zone innerZone;
    late Zone runZoneTextScaleFactor;
    late Zone runZonePlatformBrightness;
    late double? textScaleFactor;
    late Brightness? platformBrightness;

    runZoned(() {
      innerZone = Zone.current;
      window.onTextScaleFactorChanged = () {
        runZoneTextScaleFactor = Zone.current;
        textScaleFactor = window.textScaleFactor;
      };
      window.onPlatformBrightnessChanged = () {
        runZonePlatformBrightness = Zone.current;
        platformBrightness = window.platformBrightness;
      };
    });

    window.onTextScaleFactorChanged!();

    _callHook('_updateUserSettingsData', 1, '{"textScaleFactor": 0.5, "platformBrightness": "light", "alwaysUse24HourFormat": true}');
    expectIdentical(runZoneTextScaleFactor, innerZone);
    expectEquals(textScaleFactor, 0.5);

    textScaleFactor = null;
    platformBrightness = null;

    window.onPlatformBrightnessChanged!();
    _callHook('_updateUserSettingsData', 1, '{"textScaleFactor": 0.5, "platformBrightness": "dark", "alwaysUse24HourFormat": true}');
    expectIdentical(runZonePlatformBrightness, innerZone);
    expectEquals(platformBrightness, Brightness.dark);
  });

  test('onFrameDataChanged preserves callback zone', () {
    late Zone innerZone;
    late Zone runZone;
    late int frameNumber;

    runZoned(() {
      innerZone = Zone.current;
      window.onFrameDataChanged = () {
        runZone = Zone.current;
        frameNumber = window.frameData.frameNumber;
      };
    });

    _callHook('_beginFrame', 2, 0, 2);
    expectNotEquals(runZone, null);
    expectIdentical(runZone, innerZone);
    expectEquals(frameNumber, 2);
  });

  _finish();
}

void _callHook(
  String name, [
  int argCount = 0,
  Object? arg0,
  Object? arg1,
  Object? arg2,
  Object? arg3,
  Object? arg4,
  Object? arg5,
  Object? arg6,
  Object? arg8,
  Object? arg9,
  Object? arg10,
  Object? arg11,
  Object? arg12,
  Object? arg13,
  Object? arg14,
  Object? arg15,
  Object? arg16,
  Object? arg17,
]) native 'CallHook';

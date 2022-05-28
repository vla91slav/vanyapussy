package io.flutter.embedding.android;

import static io.flutter.embedding.android.FlutterActivityLaunchConfigs.HANDLE_DEEPLINKING_META_DATA_KEY;
import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.robolectric.Shadows.shadowOf;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.LifecycleOwner;
import io.flutter.FlutterInjector;
import io.flutter.TestUtils;
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterJNI;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener;
import io.flutter.plugins.GeneratedPluginRegistrant;
import java.util.List;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.android.controller.ActivityController;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
public class FlutterActivityTest {
  @Before
  public void setUp() {
    GeneratedPluginRegistrant.clearRegisteredEngines();
    FlutterJNI mockFlutterJNI = mock(FlutterJNI.class);
    when(mockFlutterJNI.isAttached()).thenReturn(true);
    FlutterJNI.Factory mockFlutterJNIFactory = mock(FlutterJNI.Factory.class);
    when(mockFlutterJNIFactory.provideFlutterJNI()).thenReturn(mockFlutterJNI);
    FlutterInjector.setInstance(
        new FlutterInjector.Builder().setFlutterJNIFactory(mockFlutterJNIFactory).build());
  }

  @After
  public void tearDown() {
    GeneratedPluginRegistrant.clearRegisteredEngines();
    FlutterInjector.reset();
  }

  @Test
  public void flutterViewHasId() {
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity activity = activityController.get();

    activity.onCreate(null);
    assertNotNull(activity.findViewById(FlutterActivity.FLUTTER_VIEW_ID));
    assertTrue(activity.findViewById(FlutterActivity.FLUTTER_VIEW_ID) instanceof FlutterView);
  }

  @Test
  public void itCreatesDefaultIntentWithExpectedDefaults() {
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    flutterActivity.setDelegate(new FlutterActivityAndFragmentDelegate(flutterActivity));

    assertEquals("main", flutterActivity.getDartEntrypointFunctionName());
    assertEquals("/", flutterActivity.getInitialRoute());
    assertArrayEquals(new String[] {}, flutterActivity.getFlutterShellArgs().toArray());
    assertTrue(flutterActivity.shouldAttachEngineToActivity());
    assertNull(flutterActivity.getCachedEngineId());
    assertTrue(flutterActivity.shouldDestroyEngineWithHost());
    assertEquals(BackgroundMode.opaque, flutterActivity.getBackgroundMode());
    assertEquals(RenderMode.surface, flutterActivity.getRenderMode());
    assertEquals(TransparencyMode.opaque, flutterActivity.getTransparencyMode());
  }

  @Test
  public void itDestroysNewEngineWhenIntentIsMissingParameter() {
    // All clients should use the static members of FlutterActivity to construct an
    // Intent. Missing extras is an error. However, Flutter has number of tests that
    // don't seem to use the static members of FlutterActivity to construct the
    // launching Intent, so this test explicitly verifies that even illegal Intents
    // result in the automatic destruction of a non-cached FlutterEngine, which prevents
    // the breakage of memory usage benchmark tests.
    Intent intent = new Intent(RuntimeEnvironment.application, FlutterActivity.class);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    flutterActivity.setDelegate(new FlutterActivityAndFragmentDelegate(flutterActivity));

    assertTrue(flutterActivity.shouldDestroyEngineWithHost());
  }

  @Test
  public void itDoesNotDestroyFlutterEngineWhenProvidedByHost() {
    Intent intent =
        new Intent(RuntimeEnvironment.application, FlutterActivityWithProvidedEngine.class);
    ActivityController<FlutterActivityWithProvidedEngine> activityController =
        Robolectric.buildActivity(FlutterActivityWithProvidedEngine.class, intent);
    activityController.create();
    FlutterActivityWithProvidedEngine flutterActivity = activityController.get();

    assertFalse(flutterActivity.shouldDestroyEngineWithHost());
  }

  @Test
  public void itCreatesNewEngineIntentWithRequestedSettings() {
    Intent intent =
        FlutterActivity.withNewEngine()
            .initialRoute("/custom/route")
            .backgroundMode(BackgroundMode.transparent)
            .build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    flutterActivity.setDelegate(new FlutterActivityAndFragmentDelegate(flutterActivity));

    assertEquals("/custom/route", flutterActivity.getInitialRoute());
    assertArrayEquals(new String[] {}, flutterActivity.getFlutterShellArgs().toArray());
    assertTrue(flutterActivity.shouldAttachEngineToActivity());
    assertNull(flutterActivity.getCachedEngineId());
    assertTrue(flutterActivity.shouldDestroyEngineWithHost());
    assertEquals(BackgroundMode.transparent, flutterActivity.getBackgroundMode());
    assertEquals(RenderMode.texture, flutterActivity.getRenderMode());
    assertEquals(TransparencyMode.transparent, flutterActivity.getTransparencyMode());
  }

  @Test
  public void itReturnsValueFromMetaDataWhenCallsShouldHandleDeepLinkingCase1()
      throws PackageManager.NameNotFoundException {
    Intent intent =
        FlutterActivity.withNewEngine()
            .backgroundMode(BackgroundMode.transparent)
            .build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    Bundle bundle = new Bundle();
    bundle.putBoolean(HANDLE_DEEPLINKING_META_DATA_KEY, true);
    FlutterActivity spyFlutterActivity = spy(flutterActivity);
    when(spyFlutterActivity.getMetaData()).thenReturn(bundle);
    assertTrue(spyFlutterActivity.shouldHandleDeeplinking());
  }

  @Test
  public void itReturnsValueFromMetaDataWhenCallsShouldHandleDeepLinkingCase2()
      throws PackageManager.NameNotFoundException {
    Intent intent =
        FlutterActivity.withNewEngine()
            .backgroundMode(BackgroundMode.transparent)
            .build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    Bundle bundle = new Bundle();
    bundle.putBoolean(HANDLE_DEEPLINKING_META_DATA_KEY, false);
    FlutterActivity spyFlutterActivity = spy(flutterActivity);
    when(spyFlutterActivity.getMetaData()).thenReturn(bundle);
    assertFalse(spyFlutterActivity.shouldHandleDeeplinking());
  }

  @Test
  public void itReturnsValueFromMetaDataWhenCallsShouldHandleDeepLinkingCase3()
      throws PackageManager.NameNotFoundException {
    Intent intent =
        FlutterActivity.withNewEngine()
            .backgroundMode(BackgroundMode.transparent)
            .build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    // Creates an empty bundle.
    Bundle bundle = new Bundle();
    FlutterActivity spyFlutterActivity = spy(flutterActivity);
    when(spyFlutterActivity.getMetaData()).thenReturn(bundle);
    // Empty bundle should return false.
    assertFalse(spyFlutterActivity.shouldHandleDeeplinking());
  }

  @Test
  public void itCreatesCachedEngineIntentThatDoesNotDestroyTheEngine() {
    Intent intent =
        FlutterActivity.withCachedEngine("my_cached_engine")
            .destroyEngineWithActivity(false)
            .build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    assertArrayEquals(new String[] {}, flutterActivity.getFlutterShellArgs().toArray());
    assertTrue(flutterActivity.shouldAttachEngineToActivity());
    assertEquals("my_cached_engine", flutterActivity.getCachedEngineId());
    assertFalse(flutterActivity.shouldDestroyEngineWithHost());
  }

  @Test
  public void itCreatesCachedEngineIntentThatDestroysTheEngine() {
    Intent intent =
        FlutterActivity.withCachedEngine("my_cached_engine")
            .destroyEngineWithActivity(true)
            .build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    assertArrayEquals(new String[] {}, flutterActivity.getFlutterShellArgs().toArray());
    assertTrue(flutterActivity.shouldAttachEngineToActivity());
    assertEquals("my_cached_engine", flutterActivity.getCachedEngineId());
    assertTrue(flutterActivity.shouldDestroyEngineWithHost());
  }

  @Test
  public void itRegistersPluginsAtConfigurationTime() {
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity activity = activityController.get();

    // This calls onAttach on FlutterActivityAndFragmentDelegate and subsequently
    // configureFlutterEngine which registers the plugins.
    activity.onCreate(null);

    List<FlutterEngine> registeredEngines = GeneratedPluginRegistrant.getRegisteredEngines();
    assertEquals(1, registeredEngines.size());
    assertEquals(activity.getFlutterEngine(), registeredEngines.get(0));
  }

  @Test
  public void itCanBeDetachedFromTheEngineAndStopSendingFurtherEvents() {
    FlutterActivityAndFragmentDelegate mockDelegate =
        mock(FlutterActivityAndFragmentDelegate.class);
    FlutterEngine mockEngine = mock(FlutterEngine.class);
    FlutterEngineCache.getInstance().put("my_cached_engine", mockEngine);

    Intent intent =
        FlutterActivity.withCachedEngine("my_cached_engine").build(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();
    flutterActivity.setDelegate(mockDelegate);
    flutterActivity.onStart();
    flutterActivity.onResume();

    verify(mockDelegate, times(1)).onStart();
    verify(mockDelegate, times(1)).onResume();

    flutterActivity.onPause();
    flutterActivity.detachFromFlutterEngine();
    verify(mockDelegate, times(1)).onPause();
    verify(mockDelegate, times(1)).onDestroyView();
    verify(mockDelegate, times(1)).onDetach();

    flutterActivity.onStop();
    verify(mockDelegate, never()).onStop();

    // Simulate the disconnected activity resuming again.
    flutterActivity.onStart();
    flutterActivity.onResume();
    // Shouldn't send more events to the delegates as before and shouldn't crash.
    verify(mockDelegate, times(1)).onStart();
    verify(mockDelegate, times(1)).onResume();

    flutterActivity.onDestroy();
    // 1 time same as before.
    verify(mockDelegate, times(1)).onDestroyView();
    verify(mockDelegate, times(1)).onDetach();
  }

  @Test
  public void itDelaysDrawing() {
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    flutterActivity.onCreate(null);

    assertNotNull(flutterActivity.delegate.activePreDrawListener);
  }

  @Test
  public void itDoesNotDelayDrawingwhenUsingTextureRendering() {
    Intent intent =
        FlutterActivityWithTextureRendering.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivityWithTextureRendering> activityController =
        Robolectric.buildActivity(FlutterActivityWithTextureRendering.class, intent);
    FlutterActivityWithTextureRendering flutterActivity = activityController.get();

    flutterActivity.onCreate(null);

    assertNull(flutterActivity.delegate.activePreDrawListener);
  }

  @Test
  public void itRestoresPluginStateBeforePluginOnCreate() {
    FlutterLoader mockFlutterLoader = mock(FlutterLoader.class);
    FlutterJNI mockFlutterJni = mock(FlutterJNI.class);
    when(mockFlutterJni.isAttached()).thenReturn(true);
    FlutterEngine cachedEngine =
        new FlutterEngine(RuntimeEnvironment.application, mockFlutterLoader, mockFlutterJni);
    FakeFlutterPlugin fakeFlutterPlugin = new FakeFlutterPlugin();
    cachedEngine.getPlugins().add(fakeFlutterPlugin);
    FlutterEngineCache.getInstance().put("my_cached_engine", cachedEngine);

    Intent intent =
        FlutterActivity.withCachedEngine("my_cached_engine").build(RuntimeEnvironment.application);
    Robolectric.buildActivity(FlutterActivity.class, intent).setup();
    assertTrue(
        "Expected FakeFlutterPlugin onCreateCalled to be true", fakeFlutterPlugin.onCreateCalled);
  }

  @Test
  public void itDoesNotRegisterPluginsTwiceWhenUsingACachedEngine() {
    Intent intent =
        new Intent(RuntimeEnvironment.application, FlutterActivityWithProvidedEngine.class);
    ActivityController<FlutterActivityWithProvidedEngine> activityController =
        Robolectric.buildActivity(FlutterActivityWithProvidedEngine.class, intent);
    activityController.create();
    FlutterActivityWithProvidedEngine flutterActivity = activityController.get();
    flutterActivity.configureFlutterEngine(flutterActivity.getFlutterEngine());

    List<FlutterEngine> registeredEngines = GeneratedPluginRegistrant.getRegisteredEngines();
    // This might cause the plugins to be registered twice, once by the FlutterEngine constructor,
    // and once by the default FlutterActivity.configureFlutterEngine implementation.
    // Test that it doesn't happen.
    assertEquals(1, registeredEngines.size());
  }

  @Test
  public void itDoesNotCrashWhenSplashScreenMetadataIsNotDefined() {
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    // We never supplied the metadata to the robolectric activity info so it doesn't exist.
    SplashScreen splashScreen = flutterActivity.provideSplashScreen();
    // It should quietly return a null and not crash.
    assertNull(splashScreen);
  }

  @Test
  @Config(shadows = {SplashShadowResources.class})
  public void itLoadsSplashScreenDrawable() throws PackageManager.NameNotFoundException {
    TestUtils.setApiVersion(19);
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    // Inject splash screen drawable resource id in the metadata.
    PackageManager pm = RuntimeEnvironment.application.getPackageManager();
    ActivityInfo activityInfo =
        pm.getActivityInfo(flutterActivity.getComponentName(), PackageManager.GET_META_DATA);
    activityInfo.metaData = new Bundle();
    activityInfo.metaData.putInt(
        FlutterActivityLaunchConfigs.SPLASH_SCREEN_META_DATA_KEY,
        SplashShadowResources.SPLASH_DRAWABLE_ID);
    shadowOf(RuntimeEnvironment.application.getPackageManager()).addOrUpdateActivity(activityInfo);

    // It should load the drawable.
    SplashScreen splashScreen = flutterActivity.provideSplashScreen();
    assertNotNull(splashScreen);
  }

  @Test
  @Config(shadows = {SplashShadowResources.class})
  @TargetApi(21) // Theme references in drawables requires API 21+
  public void itLoadsThemedSplashScreenDrawable() throws PackageManager.NameNotFoundException {
    // A drawable with theme references can be parsed only if the app theme is supplied
    // in getDrawable methods. This test verifies it by fetching a (fake) themed drawable.
    // On failure, a Resource.NotFoundException will ocurr.
    TestUtils.setApiVersion(21);
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    // Inject themed splash screen drawable resource id in the metadata.
    PackageManager pm = RuntimeEnvironment.application.getPackageManager();
    ActivityInfo activityInfo =
        pm.getActivityInfo(flutterActivity.getComponentName(), PackageManager.GET_META_DATA);
    activityInfo.metaData = new Bundle();
    activityInfo.metaData.putInt(
        FlutterActivityLaunchConfigs.SPLASH_SCREEN_META_DATA_KEY,
        SplashShadowResources.THEMED_SPLASH_DRAWABLE_ID);
    shadowOf(RuntimeEnvironment.application.getPackageManager()).addOrUpdateActivity(activityInfo);

    // It should load the drawable.
    SplashScreen splashScreen = flutterActivity.provideSplashScreen();
    assertNotNull(splashScreen);
  }

  @Test
  public void itWithMetadataWithoutSplashScreenResourceKeyDoesNotProvideSplashScreen()
      throws PackageManager.NameNotFoundException {
    Intent intent = FlutterActivity.createDefaultIntent(RuntimeEnvironment.application);
    ActivityController<FlutterActivity> activityController =
        Robolectric.buildActivity(FlutterActivity.class, intent);
    FlutterActivity flutterActivity = activityController.get();

    // Setup an empty metadata file.
    PackageManager pm = RuntimeEnvironment.application.getPackageManager();
    ActivityInfo activityInfo =
        pm.getActivityInfo(flutterActivity.getComponentName(), PackageManager.GET_META_DATA);
    activityInfo.metaData = new Bundle();
    shadowOf(RuntimeEnvironment.application.getPackageManager()).addOrUpdateActivity(activityInfo);

    // It should not load the drawable.
    SplashScreen splashScreen = flutterActivity.provideSplashScreen();
    assertNull(splashScreen);
  }

  static class FlutterActivityWithProvidedEngine extends FlutterActivity {
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
      super.delegate = new FlutterActivityAndFragmentDelegate(this);
      super.delegate.setupFlutterEngine();
    }

    @Nullable
    @Override
    public FlutterEngine provideFlutterEngine(@NonNull Context context) {
      FlutterJNI flutterJNI = mock(FlutterJNI.class);
      FlutterLoader flutterLoader = mock(FlutterLoader.class);
      when(flutterJNI.isAttached()).thenReturn(true);
      when(flutterLoader.automaticallyRegisterPlugins()).thenReturn(true);

      return new FlutterEngine(context, flutterLoader, flutterJNI, new String[] {}, true);
    }
  }

  // This is just a compile time check to ensure that it's possible for FlutterActivity subclasses
  // to provide their own intent builders which builds their own runtime types.
  static class FlutterActivityWithIntentBuilders extends FlutterActivity {

    public static NewEngineIntentBuilder withNewEngine() {
      return new NewEngineIntentBuilder(FlutterActivityWithIntentBuilders.class);
    }

    public static CachedEngineIntentBuilder withCachedEngine(@NonNull String cachedEngineId) {
      return new CachedEngineIntentBuilder(FlutterActivityWithIntentBuilders.class, cachedEngineId);
    }
  }

  private static class FlutterActivityWithTextureRendering extends FlutterActivity {
    @Override
    public RenderMode getRenderMode() {
      return RenderMode.texture;
    }
  }

  private static final class FakeFlutterPlugin
      implements FlutterPlugin,
          ActivityAware,
          OnSaveInstanceStateListener,
          DefaultLifecycleObserver {

    private ActivityPluginBinding activityPluginBinding;
    private boolean stateRestored = false;
    private boolean onCreateCalled = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {}

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
      activityPluginBinding = binding;
      binding.addOnSaveStateListener(this);
      ((FlutterActivity) binding.getActivity()).getLifecycle().addObserver(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
      onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
      onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
      ((FlutterActivity) activityPluginBinding.getActivity()).getLifecycle().removeObserver(this);
      activityPluginBinding.removeOnSaveStateListener(this);
      activityPluginBinding = null;
    }

    @Override
    public void onSaveInstanceState(@NonNull Bundle bundle) {}

    @Override
    public void onRestoreInstanceState(@Nullable Bundle bundle) {
      stateRestored = true;
    }

    @Override
    public void onCreate(@NonNull LifecycleOwner lifecycleOwner) {
      assertTrue("State was restored before onCreate", stateRestored);
      onCreateCalled = true;
    }
  }
}

/**
 * WalkMe React Native SDK — example app.
 *
 * Exercises every public API of `@walkme-mobile/react-native-sdk` against the
 * real package, installed the way a consumer installs it. The same file is
 * used by both example apps:
 *
 *   examples/new-arch/  React Native 0.85.x — New Architecture (TurboModule)
 *   examples/legacy/    React Native 0.81.x — Legacy Architecture (NativeModule)
 *
 * and by both WalkMe flavors (`walkme.walkmeMode` in the app's package.json:
 * `WalkMe` or `WalkMeEditor`/Power Mode). Nothing below is architecture- or
 * flavor-aware, which is the point: the JavaScript API is identical everywhere.
 */

import React, {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import {
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import {SafeAreaProvider, SafeAreaView} from 'react-native-safe-area-context';

import WalkMeSDK from '@walkme-mobile/react-native-sdk';
import type {WMAnalyticsEvent, WMItemInfo} from '@walkme-mobile/react-native-sdk';

// Replace with a GUID from your WalkMe console to see real content. The example
// is still useful without one: every call goes through the bridge to the native
// SDK, so a wrong GUID exercises the exact same code path.
const SYSTEM_GUID = 'PUT-YOUR-SYSTEM-GUID-HERE';

/**
 * Which React Native architecture is actually running. Purely informational —
 * the SDK itself never asks. `__turboModuleProxy` is installed by the
 * TurboModule system; `RN$Bridgeless` additionally means there is no bridge.
 */
function describeArchitecture(): string {
  const g = globalThis as unknown as Record<string, unknown>;
  const bridgeless = g.RN$Bridgeless === true;
  const turbo = g.__turboModuleProxy != null;
  if (bridgeless) {
    return 'New Architecture (bridgeless)';
  }
  return turbo ? 'New Architecture (TurboModules)' : 'Legacy Architecture';
}

export default function App(): React.JSX.Element {
  const isDark = useColorScheme() === 'dark';
  const [log, setLog] = useState<string[]>([]);
  const [itemInfoOn, setItemInfoOn] = useState(false);
  const [analyticsOn, setAnalyticsOn] = useState(false);
  const counter = useRef(0);

  const append = useCallback((line: string) => {
    setLog(prev => [`${new Date().toLocaleTimeString()}  ${line}`, ...prev].slice(0, 200));
  }, []);

  // start() once on mount, mirroring the documented quick-start.
  useEffect(() => {
    append(`architecture: ${describeArchitecture()}`);
    try {
      WalkMeSDK.start({
        systemGuid: SYSTEM_GUID,
        environment: 'Production',
        dataCenter: 'prod',
        analyticsEnabled: true,
        localLogsEnabled: true,
      });
      append('start({...}) -> ok');
    } catch (e) {
      append(`start() threw: ${String(e)}`);
    }
    return () => {
      // Detach both listeners so a Fast Refresh / reload does not leave the
      // native SDK holding a callback into a dead JS runtime.
      WalkMeSDK.setItemInfoListener(null);
      WalkMeSDK.setAnalyticsListener(null);
    };
  }, [append]);

  const run = useCallback(
    (label: string, fn: () => void) => () => {
      try {
        fn();
        append(`${label} -> ok`);
      } catch (e) {
        append(`${label} THREW: ${String(e)}`);
      }
    },
    [append],
  );

  const toggleItemInfo = useCallback(() => {
    const next = !itemInfoOn;
    setItemInfoOn(next);
    if (!next) {
      WalkMeSDK.setItemInfoListener(null);
      append('setItemInfoListener(null) -> ok');
      return;
    }
    WalkMeSDK.setItemInfoListener({
      onItemPresented: (info: WMItemInfo) => append(`EVENT onItemPresented itemId=${info.itemId}`),
      onItemDismissed: (info: WMItemInfo) => append(`EVENT onItemDismissed itemId=${info.itemId}`),
      // Android only — iOS's WalkMe SDK has no item-action callback.
      onItemAction: (info: WMItemInfo) =>
        append(`EVENT onItemAction itemId=${info.itemId} type=${info.itemActionType}`),
    });
    append('setItemInfoListener({...}) -> ok');
  }, [append, itemInfoOn]);

  const toggleAnalytics = useCallback(() => {
    const next = !analyticsOn;
    setAnalyticsOn(next);
    if (!next) {
      WalkMeSDK.setAnalyticsListener(null);
      append('setAnalyticsListener(null) -> ok');
      return;
    }
    WalkMeSDK.setAnalyticsListener((event: WMAnalyticsEvent) =>
      append(`EVENT analytics ${event.eventName} ${event.params?.slice(0, 80)}`),
    );
    append('setAnalyticsListener(fn) -> ok');
  }, [append, analyticsOn]);

  const actions = useMemo(
    () => [
      {label: 'start()', onPress: run('start()', () => WalkMeSDK.start({systemGuid: SYSTEM_GUID}))},
      {label: 'stop()', onPress: run('stop()', () => WalkMeSDK.stop())},
      {label: 'restart()', onPress: run('restart()', () => WalkMeSDK.restart())},
      {
        label: 'startItemByID(42)',
        onPress: run('startItemByID(42, null)', () => WalkMeSDK.startItemByID(42, null)),
      },
      {
        label: 'startItemByID(42, deepLink)',
        onPress: run('startItemByID(42, "walkme://demo")', () =>
          WalkMeSDK.startItemByID(42, 'walkme://demo'),
        ),
      },
      {label: 'dismissItem()', onPress: run('dismissItem()', () => WalkMeSDK.dismissItem())},
      {
        label: 'setUserId("user-123")',
        onPress: run('setUserId("user-123")', () => WalkMeSDK.setUserId('user-123')),
      },
      {label: 'setUserId(null)', onPress: run('setUserId(null)', () => WalkMeSDK.setUserId(null))},
      {
        label: 'setVariable("plan","premium")',
        onPress: run('setVariable("plan","premium")', () =>
          WalkMeSDK.setVariable('plan', 'premium'),
        ),
      },
      {
        label: 'setVariable("plan",null)',
        onPress: run('setVariable("plan",null)', () => WalkMeSDK.setVariable('plan', null)),
      },
      {
        label: 'setEventUserVars({...})',
        onPress: run('setEventUserVars({name,role,type,status,info})', () =>
          WalkMeSDK.setEventUserVars({
            name: 'John Doe',
            role: 'admin',
            type: 'internal',
            status: 'active',
            info: 'example app',
          }),
        ),
      },
      {
        label: 'setLanguage("en")',
        onPress: run('setLanguage("en")', () => WalkMeSDK.setLanguage('en')),
      },
      {
        label: 'sendEvent(name, attrs)',
        onPress: run('sendEvent("button_clicked", {...})', () => {
          counter.current += 1;
          WalkMeSDK.sendEvent('button_clicked', {
            screen: 'home',
            count: String(counter.current),
          });
        }),
      },
      {
        label: 'sendEvent(name)',
        onPress: run('sendEvent("bare_event")', () => WalkMeSDK.sendEvent('bare_event')),
      },
    ],
    [run],
  );

  const theme = isDark ? styles.dark : styles.light;

  return (
    <SafeAreaProvider>
      <SafeAreaView style={[styles.root, theme]}>
        <Text style={[styles.title, theme]}>WalkMe SDK example</Text>
        <Text style={[styles.subtitle, theme]}>
          {Platform.OS} · RN {String(Platform.constants?.reactNativeVersion?.minor ?? '?')} ·{' '}
          {describeArchitecture()}
        </Text>

        <ScrollView style={styles.buttons} contentContainerStyle={styles.buttonsContent}>
          {actions.map(a => (
            <Pressable key={a.label} onPress={a.onPress} style={styles.button}>
              <Text style={styles.buttonText}>{a.label}</Text>
            </Pressable>
          ))}
          <Pressable
            onPress={toggleItemInfo}
            style={[styles.button, itemInfoOn && styles.buttonOn]}>
            <Text style={styles.buttonText}>
              item-info listener: {itemInfoOn ? 'ON (tap to clear)' : 'OFF (tap to set)'}
            </Text>
          </Pressable>
          <Pressable
            onPress={toggleAnalytics}
            style={[styles.button, analyticsOn && styles.buttonOn]}>
            <Text style={styles.buttonText}>
              analytics listener: {analyticsOn ? 'ON (tap to clear)' : 'OFF (tap to set)'}
            </Text>
          </Pressable>
        </ScrollView>

        <Text style={[styles.title, theme]}>Log</Text>
        <ScrollView style={styles.logBox}>
          {log.map((line, i) => (
            <Text key={`${i}-${line}`} style={[styles.logLine, theme]}>
              {line}
            </Text>
          ))}
        </ScrollView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, paddingHorizontal: 12},
  light: {backgroundColor: '#fff', color: '#111'},
  dark: {backgroundColor: '#111', color: '#eee'},
  title: {fontSize: 18, fontWeight: '600', marginTop: 8},
  subtitle: {fontSize: 12, marginBottom: 8, opacity: 0.7},
  buttons: {flex: 3},
  buttonsContent: {paddingBottom: 8},
  button: {
    backgroundColor: '#2b6cb0',
    borderRadius: 6,
    marginVertical: 3,
    paddingHorizontal: 10,
    paddingVertical: 9,
  },
  buttonOn: {backgroundColor: '#2f855a'},
  buttonText: {color: '#fff', fontSize: 13},
  logBox: {flex: 2, marginBottom: 8},
  logLine: {fontSize: 11, fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace'},
});

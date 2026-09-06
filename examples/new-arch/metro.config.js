const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * The WalkMe bridge is installed as `file:../..` — a link straight to this
 * repository's checkout — so the example always runs the SDK sources currently
 * on the branch. Two consequences Metro has to be told about:
 *
 *   1. The SDK lives outside this app's folder, so it has to be watched
 *      explicitly or edits to it will not be picked up.
 *   2. The repository root has its own `node_modules`: React and React Native
 *      are dev dependencies there, for codegen and type-checking. Metro
 *      resolves through the link to the real path, so without the block list
 *      below it would load *that* copy of React Native alongside this app's —
 *      a different version in the Legacy example, a duplicate module instance
 *      in both. Only this app's copies may ever be loaded.
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const projectRoot = __dirname;
const sdkRoot = path.resolve(projectRoot, '../..');

const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const defaultConfig = getDefaultConfig(projectRoot);

const config = {
  watchFolders: [sdkRoot],
  resolver: {
    blockList: new RegExp(
      `${defaultConfig.resolver.blockList.source}` +
        `|^${escapeRegExp(path.join(sdkRoot, 'node_modules'))}[\\\\/].*$`,
    ),
    // Anything the linked SDK requires resolves to this app's dependencies.
    extraNodeModules: new Proxy(
      {},
      {get: (_target, name) => path.join(projectRoot, 'node_modules', name)},
    ),
  },
};

module.exports = mergeConfig(defaultConfig, config);

module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.walkme.rn.RNWalkMeSdkPackage;',
        packageInstance: 'new RNWalkMeSdkPackage()',
      },
      // iOS is autolinked via walkme-react-native-sdk.podspec, which pulls the
      // SPM-only WalkMe SDK through React Native's spm_dependency helper (RN >= 0.75).
      ios: {},
    },
  },
};

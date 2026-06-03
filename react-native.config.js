module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.walkme.rn.RNWalkMeSdkPackage;',
        packageInstance: 'new RNWalkMeSdkPackage()',
      },
      // iOS is integrated via SPM — add the package manually in Xcode.
      // No podspec is provided intentionally.
      ios: null,
    },
  },
};

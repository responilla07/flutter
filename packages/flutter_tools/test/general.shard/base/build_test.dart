// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';

import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/base/build.dart';
import 'package:flutter_tools/src/ios/xcodeproj.dart';
import 'package:flutter_tools/src/macos/xcode.dart';

import '../../src/common.dart';
import '../../src/context.dart';

const FakeCommand kSdkPathCommand = FakeCommand(
  command: <String>[
    'xcrun',
    '--sdk',
    'iphoneos',
    '--show-sdk-path'
  ]
);

const List<String> kDefaultClang = <String>[
  '-miphoneos-version-min=8.0',
  '-dynamiclib',
  '-Xlinker',
  '-rpath',
  '-Xlinker',
  '@executable_path/Frameworks',
  '-Xlinker',
  '-rpath',
  '-Xlinker',
  '@loader_path/Frameworks',
  '-install_name',
  '@rpath/App.framework/App',
  '-isysroot',
  '',
  '-o',
  'build/foo/App.framework/App',
  'build/foo/snapshot_assembly.o',
];

const List<String> kBitcodeClang = <String>[
  '-miphoneos-version-min=8.0',
  '-dynamiclib',
  '-Xlinker',
  '-rpath',
  '-Xlinker',
  '@executable_path/Frameworks',
  '-Xlinker',
  '-rpath',
  '-Xlinker',
  '@loader_path/Frameworks',
  '-install_name',
  '@rpath/App.framework/App',
  '-fembed-bitcode',
  '-isysroot',
  '',
  '-o',
  'build/foo/App.framework/App',
  'build/foo/snapshot_assembly.o',
];

void main() {
  group('SnapshotType', () {
    test('throws, if build mode is null', () {
      expect(
        () => SnapshotType(TargetPlatform.android_x64, null),
        throwsA(anything),
      );
    });
    test('does not throw, if target platform is null', () {
      expect(() => SnapshotType(null, BuildMode.release), returnsNormally);
    });
  });

  group('GenSnapshot', () {
    GenSnapshot genSnapshot;
    MockArtifacts mockArtifacts;
    FakeProcessManager processManager;
    BufferLogger logger;

    setUp(() async {
      mockArtifacts = MockArtifacts();
      logger = BufferLogger.test();
      processManager = FakeProcessManager.list(<  FakeCommand>[]);
      genSnapshot = GenSnapshot(
        artifacts: mockArtifacts,
        logger: logger,
        processManager: processManager,
      );
      when(mockArtifacts.getArtifactPath(
        any,
        platform: anyNamed('platform'),
        mode: anyNamed('mode'),
      )).thenReturn('gen_snapshot');
    });

    testWithoutContext('android_x64', () async {
      processManager.addCommand(const FakeCommand(
        command: <String>['gen_snapshot', '--additional_arg']
      ));

      final int result = await genSnapshot.run(
        snapshotType: SnapshotType(TargetPlatform.android_x64, BuildMode.release),
        darwinArch: null,
        additionalArgs: <String>['--additional_arg'],
      );
      expect(result, 0);
    });

    testWithoutContext('iOS armv7', () async {
      processManager.addCommand(const FakeCommand(
        command: <String>['gen_snapshot_armv7', '--additional_arg']
      ));

      final int result = await genSnapshot.run(
        snapshotType: SnapshotType(TargetPlatform.ios, BuildMode.release),
        darwinArch: DarwinArch.armv7,
        additionalArgs: <String>['--additional_arg'],
      );
      expect(result, 0);
    });

    testWithoutContext('iOS arm64', () async {
      processManager.addCommand(const FakeCommand(
        command: <String>['gen_snapshot_arm64', '--additional_arg']
      ));

      final int result = await genSnapshot.run(
        snapshotType: SnapshotType(TargetPlatform.ios, BuildMode.release),
        darwinArch: DarwinArch.arm64,
        additionalArgs: <String>['--additional_arg'],
      );
      expect(result, 0);
    });

    testWithoutContext('--strip filters error output from gen_snapshot', () async {
        processManager.addCommand(FakeCommand(
        command: const <String>['gen_snapshot', '--strip'],
        stderr: 'ABC\n${GenSnapshot.kIgnoredWarnings.join('\n')}\nXYZ\n'
      ));

  group('Snapshotter - AOT', () {
    const String kSnapshotDart = 'snapshot.dart';
    const String kSDKPath = '/path/to/sdk';
    String skyEnginePath;

  group('AOTSnapshotter', () {
    MemoryFileSystem fileSystem;
    AOTSnapshotter snapshotter;
    MockArtifacts mockArtifacts;
    FakeProcessManager processManager;
    Logger logger;

    setUp(() async {
      final Platform platform = FakePlatform(operatingSystem: 'macos');
      logger = BufferLogger.test();
      fileSystem = MemoryFileSystem.test();
      mockArtifacts = MockArtifacts();
      mockXcode = MockXcode();
      when(mockXcode.sdkLocation(any)).thenAnswer((_) => Future<String>.value(kSDKPath));

      bufferLogger = BufferLogger();
      for (BuildMode mode in BuildMode.values) {
        when(mockArtifacts.getArtifactPath(Artifact.snapshotDart,
            platform: anyNamed('platform'), mode: mode)).thenReturn(kSnapshotDart);
      }
    });

    testWithoutContext('does not build iOS with debug build mode', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');

      expect(await snapshotter.build(
        platform: TargetPlatform.ios,
        darwinArch: DarwinArch.arm64,
        buildMode: BuildMode.debug,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      ), isNot(equals(0)));
    });

    testWithoutContext('does not build android-arm with debug build mode', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');

      expect(await snapshotter.build(
        platform: TargetPlatform.android_arm,
        buildMode: BuildMode.debug,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      ), isNot(0));
    });

    testWithoutContext('does not build android-arm64 with debug build mode', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');

      expect(await snapshotter.build(
        platform: TargetPlatform.android_arm64,
        buildMode: BuildMode.debug,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      ), isNot(0));
    });

    testWithoutContext('builds iOS with bitcode', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      final String assembly = fileSystem.path.join(outputPath, 'snapshot_assembly.S');
      processManager.addCommand(FakeCommand(
        command: <String>[
          'gen_snapshot_armv7',
          '--deterministic',
          '--snapshot_kind=app-aot-assembly',
          '--assembly=$assembly',
          '--strip',
          '--no-sim-use-hardfp',
          '--no-use-integer-division',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          'main.dill',
        ]
      ));
      processManager.addCommand(kSdkPathCommand);
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'xcrun',
          'cc',
          '-arch',
          'armv7',
          '-isysroot',
          '',
          '-fembed-bitcode',
          '-c',
          'build/foo/snapshot_assembly.S',
          '-o',
          'build/foo/snapshot_assembly.o',
        ]
      ));
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'xcrun',
          'clang',
          '-arch',
          'armv7',
          ...kBitcodeClang,
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.ios,
        buildMode: BuildMode.profile,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        darwinArch: DarwinArch.armv7,
        bitcode: true,
        splitDebugInfo: null,
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(genSnapshot.callCount, 1);
      expect(genSnapshot.snapshotType.platform, TargetPlatform.ios);
      expect(genSnapshot.snapshotType.mode, BuildMode.profile);
      expect(genSnapshot.additionalArgs, <String>[
        '--deterministic',
        '--snapshot_kind=app-aot-assembly',
        '--assembly=$assembly',
        '--no-sim-use-hardfp',
        '--no-use-integer-division',
        'main.dill',
      ]);

      final VerificationResult toVerifyCC = verify(xcode.cc(captureAny));
      expect(toVerifyCC.callCount, 1);
      final dynamic ccArgs = toVerifyCC.captured.first;
      expect(ccArgs, contains('-fembed-bitcode'));
      expect(ccArgs, contains('-isysroot'));
      expect(ccArgs, contains(kSDKPath));

      final VerificationResult toVerifyClang = verify(xcode.clang(captureAny));
      expect(toVerifyClang.callCount, 1);
      final dynamic clangArgs = toVerifyClang.captured.first;
      expect(clangArgs, contains('-fembed-bitcode'));
      expect(clangArgs, contains('-isysroot'));
      expect(clangArgs, contains(kSDKPath));

      final File assemblyFile = fs.file(assembly);
      expect(assemblyFile.existsSync(), true);
      expect(assemblyFile.readAsStringSync().contains('.section __DWARF'), true);
    }, overrides: contextOverrides);

    testUsingContext('iOS release AOT with bitcode uses right flags', () async {
      fs.file('main.dill').writeAsStringSync('binary magic');

      final String outputPath = fs.path.join('build', 'foo');
      fs.directory(outputPath).createSync(recursive: true);

      final String assembly = fs.path.join(outputPath, 'snapshot_assembly.S');
      genSnapshot.outputs = <String, String>{
        assembly: 'blah blah\n.section __DWARF\nblah blah\n',
      };

      final RunResult successResult = RunResult(ProcessResult(1, 0, '', ''), <String>['command name', 'arguments...']);
      when(xcode.cc(any)).thenAnswer((_) => Future<RunResult>.value(successResult));
      when(xcode.clang(any)).thenAnswer((_) => Future<RunResult>.value(successResult));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.ios,
        buildMode: BuildMode.profile,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        darwinArch: DarwinArch.armv7,
        bitcode: false,
        splitDebugInfo: 'foo',
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(genSnapshot.callCount, 1);
      expect(genSnapshot.snapshotType.platform, TargetPlatform.ios);
      expect(genSnapshot.snapshotType.mode, BuildMode.release);
      expect(genSnapshot.additionalArgs, <String>[
        '--deterministic',
        '--snapshot_kind=app-aot-assembly',
        '--assembly=$assembly',
        '--no-sim-use-hardfp',
        '--no-use-integer-division',
        'main.dill',
      ]);

      final VerificationResult toVerifyCC = verify(xcode.cc(captureAny));
      expect(toVerifyCC.callCount, 1);
      final dynamic ccArgs = toVerifyCC.captured.first;
      expect(ccArgs, contains('-fembed-bitcode'));
      expect(ccArgs, contains('-isysroot'));
      expect(ccArgs, contains(kSDKPath));

      final VerificationResult toVerifyClang = verify(xcode.clang(captureAny));
      expect(toVerifyClang.callCount, 1);
      final dynamic clangArgs = toVerifyClang.captured.first;
      expect(clangArgs, contains('-fembed-bitcode'));
      expect(clangArgs, contains('-isysroot'));
      expect(clangArgs, contains(kSDKPath));

      final File assemblyFile = fs.file(assembly);
      final File assemblyBitcodeFile = fs.file('$assembly.stripped.S');
      expect(assemblyFile.existsSync(), true);
      expect(assemblyBitcodeFile.existsSync(), true);
      expect(assemblyFile.readAsStringSync().contains('.section __DWARF'), true);
      expect(assemblyBitcodeFile.readAsStringSync().contains('.section __DWARF'), false);
    }, overrides: contextOverrides);

    testUsingContext('builds iOS armv7 profile AOT snapshot', () async {
      fs.file('main.dill').writeAsStringSync('binary magic');

      final String outputPath = fs.path.join('build', 'foo');
      fs.directory(outputPath).createSync(recursive: true);

      final String assembly = fs.path.join(outputPath, 'snapshot_assembly.S');
      genSnapshot.outputs = <String, String>{
        assembly: 'blah blah\n.section __DWARF\nblah blah\n',
      };

      final RunResult successResult = RunResult(ProcessResult(1, 0, '', ''), <String>['command name', 'arguments...']);
      when(xcode.cc(any)).thenAnswer((_) => Future<RunResult>.value(successResult));
      when(xcode.clang(any)).thenAnswer((_) => Future<RunResult>.value(successResult));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.ios,
        buildMode: BuildMode.profile,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        darwinArch: DarwinArch.armv7,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: true,
      );

      expect(genSnapshotExitCode, 0);
      expect(genSnapshot.callCount, 1);
      expect(genSnapshot.snapshotType.platform, TargetPlatform.ios);
      expect(genSnapshot.snapshotType.mode, BuildMode.profile);
      expect(genSnapshot.additionalArgs, <String>[
        '--deterministic',
        '--snapshot_kind=app-aot-assembly',
        '--assembly=$assembly',
        '--no-sim-use-hardfp',
        '--no-use-integer-division',
        'main.dill',
      ]);
      verifyNever(xcode.cc(argThat(contains('-fembed-bitcode'))));
      verifyNever(xcode.clang(argThat(contains('-fembed-bitcode'))));

      verify(xcode.cc(argThat(contains('-isysroot')))).called(1);
      verify(xcode.clang(argThat(contains('-isysroot')))).called(1);

      final File assemblyFile = fs.file(assembly);
      expect(assemblyFile.existsSync(), true);
      expect(assemblyFile.readAsStringSync().contains('.section __DWARF'), true);
    }, overrides: contextOverrides);

    testUsingContext('builds iOS arm64 profile AOT snapshot', () async {
      fs.file('main.dill').writeAsStringSync('binary magic');

      final String outputPath = fs.path.join('build', 'foo');
      fs.directory(outputPath).createSync(recursive: true);

      genSnapshot.outputs = <String, String>{
        fs.path.join(outputPath, 'snapshot_assembly.S'): '',
      };

      final RunResult successResult = RunResult(ProcessResult(1, 0, '', ''), <String>['command name', 'arguments...']);
      when(xcode.cc(any)).thenAnswer((_) => Future<RunResult>.value(successResult));
      when(xcode.clang(any)).thenAnswer((_) => Future<RunResult>.value(successResult));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.ios,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        darwinArch: DarwinArch.armv7,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(processManager.hasRemainingExpectations, false);
    });

    testWithoutContext('builds iOS arm64 snapshot', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      processManager.addCommand(FakeCommand(
        command: <String>[
          'gen_snapshot_arm64',
          '--deterministic',
          '--snapshot_kind=app-aot-assembly',
          '--assembly=${fileSystem.path.join(outputPath, 'snapshot_assembly.S')}',
          '--strip',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          'main.dill',
        ]
      ));
      processManager.addCommand(kSdkPathCommand);
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'xcrun',
          'cc',
          '-arch',
          'arm64',
          '-isysroot',
          '',
          '-c',
          'build/foo/snapshot_assembly.S',
          '-o',
          'build/foo/snapshot_assembly.o',
        ]
      ));
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'xcrun',
          'clang',
          '-arch',
          'arm64',
          ...kDefaultClang,
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.ios,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        darwinArch: DarwinArch.arm64,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(processManager.hasRemainingExpectations, false);
    });

    testWithoutContext('builds shared library for android-arm (32bit)', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'gen_snapshot',
          '--deterministic',
          '--snapshot_kind=app-aot-elf',
          '--elf=build/foo/app.so',
          '--strip',
          '--no-sim-use-hardfp',
          '--no-use-integer-division',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          'main.dill',
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.android_arm,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(processManager.hasRemainingExpectations, false);
    });

    testWithoutContext('builds shared library for android-arm with dwarf stack traces', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      final String debugPath = fileSystem.path.join('foo', 'app.android-arm.symbols');
      processManager.addCommand(FakeCommand(
        command: <String>[
          'gen_snapshot',
          '--deterministic',
          '--snapshot_kind=app-aot-elf',
          '--elf=build/foo/app.so',
          '--strip',
          '--no-sim-use-hardfp',
          '--no-use-integer-division',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          '--dwarf-stack-traces',
          '--save-debugging-info=$debugPath',
          'main.dill',
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.android_arm,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: 'foo',
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(processManager.hasRemainingExpectations, false);
    });

    testWithoutContext('builds shared library for android-arm with obfuscate', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'gen_snapshot',
          '--deterministic',
          '--snapshot_kind=app-aot-elf',
          '--elf=build/foo/app.so',
          '--strip',
          '--no-sim-use-hardfp',
          '--no-use-integer-division',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          '--obfuscate',
          'main.dill',
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.android_arm,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: true,
      );

      expect(genSnapshotExitCode, 0);
      expect(processManager.hasRemainingExpectations, false);
    });

    testWithoutContext('builds shared library for android-arm without dwarf stack traces due to empty string', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'gen_snapshot',
          '--deterministic',
          '--snapshot_kind=app-aot-elf',
          '--elf=build/foo/app.so',
          '--strip',
          '--no-sim-use-hardfp',
          '--no-use-integer-division',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          'main.dill',
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.android_arm,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: '',
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
       expect(processManager.hasRemainingExpectations, false);
    });

    testWithoutContext('builds shared library for android-arm64', () async {
      final String outputPath = fileSystem.path.join('build', 'foo');
      processManager.addCommand(const FakeCommand(
        command: <String>[
          'gen_snapshot',
          '--deterministic',
          '--snapshot_kind=app-aot-elf',
          '--elf=build/foo/app.so',
          '--strip',
          '--no-causal-async-stacks',
          '--lazy-async-stacks',
          'main.dill',
        ]
      ));

      final int genSnapshotExitCode = await snapshotter.build(
        platform: TargetPlatform.android_arm64,
        buildMode: BuildMode.release,
        mainPath: 'main.dill',
        packagesPath: '.packages',
        outputPath: outputPath,
        bitcode: false,
        splitDebugInfo: null,
        dartObfuscation: false,
      );

      expect(genSnapshotExitCode, 0);
      expect(processManager.hasRemainingExpectations, false);
    });
  });
}

class MockArtifacts extends Mock implements Artifacts {}

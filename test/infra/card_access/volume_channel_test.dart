import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscura_pro/infra/card_access/models.dart';
import 'package:obscura_pro/infra/card_access/volume_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const method = MethodChannel(VolumeChannel.methodChannelName);
  const events = MethodChannel(VolumeChannel.eventChannelName);
  const codec = StandardMethodCodec();

  late List<MethodCall> log;
  late Object? Function(MethodCall call) reply;

  setUp(() {
    log = <MethodCall>[];
    reply = (_) => null;
    messenger.setMockMethodCallHandler(method, (call) async {
      log.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  group('listVolumes', () {
    test('offers the card in the built-in reader and not the startup disk',
        () async {
      // Exactly what the resource keys report on a real Mac: the startup disk,
      // and a Leica card in the machine's own SD slot. That slot is on an
      // internal bus, so the card comes back `isInternal: true` — which is why
      // this fixture, and not a tidier one, is the one that matters.
      reply = (_) => <Object?>[
            <String, Object?>{
              'path': '/',
              'name': 'Macintosh HD',
              'isRemovable': false,
              'isEjectable': false,
              'isInternal': true,
              'isRoot': true,
            },
            <String, Object?>{
              'path': '/Volumes/Untitled',
              'name': 'Untitled',
              'isRemovable': true,
              'isEjectable': false,
              'isInternal': true,
              'isRoot': false,
              'freeBytes': 32000000000,
            },
          ];

      final volumes = await VolumeChannel().listVolumes();

      expect(log.single.method, 'listVolumes');
      expect(volumes.map((v) => v.name), ['Macintosh HD', 'Untitled']);
      expect(
        volumes.where((v) => v.isCardCandidate).map((v) => v.path),
        ['/Volumes/Untitled'],
      );
    });

    test('offers a card in an external reader too', () async {
      reply = (_) => <Object?>[
            <String, Object?>{
              'path': '/Volumes/LEICA Q3',
              'name': 'LEICA Q3',
              'isRemovable': true,
              'isEjectable': true,
              'isInternal': false,
              'isRoot': false,
            },
          ];

      final volume = (await VolumeChannel().listVolumes()).single;

      expect(volume.isCardCandidate, isTrue);
    });

    test('tolerates a volume whose capacity the file system did not report', () async {
      reply = (_) => <Object?>[
            <String, Object?>{
              'path': '/Volumes/NO NAME',
              'name': 'NO NAME',
              'isRemovable': true,
              'isEjectable': true,
            },
          ];

      final volume = (await VolumeChannel().listVolumes()).single;

      // Null, not zero: an unreported capacity and a full card are different
      // facts and the picker must not conflate them.
      expect(volume.freeBytes, isNull);
      expect(volume.isCardCandidate, isTrue);
    });
  });

  group('eject', () {
    test('reports success', () async {
      reply = (_) => <String, Object?>{'status': 'ejected'};

      final outcome = await VolumeChannel().eject('/Volumes/LEICA Q3');

      expect(outcome, isA<EjectSucceeded>());
      expect(log.single.arguments, <String, Object?>{'path': '/Volumes/LEICA Q3'});
    });

    test('surfaces the DiskArbitration dissenter as a readable reason', () async {
      reply = (_) => <String, Object?>{
            'status': 'refused',
            'code': 'busy',
            'dissenter': 'The disk is in use by process 431 (Preview).',
          };

      final refused =
          await VolumeChannel().eject('/Volumes/LEICA Q3') as EjectRefused;

      expect(refused.code, 'busy');
      expect(refused.message, contains('occupée'));
      expect(
        refused.message,
        contains('Preview'),
        reason: 'the user can only act on a refusal that names what holds the card',
      );
    });

    test('still explains a refusal that carries no dissenter text', () async {
      reply = (_) => <String, Object?>{'status': 'refused', 'code': 'notPermitted'};

      final refused =
          await VolumeChannel().eject('/Volumes/LEICA Q3') as EjectRefused;

      expect(refused.message, isNotEmpty);
      expect(refused.message, isNot(contains('null')));
    });

    test('distinguishes a volume that is not mounted', () async {
      reply = (_) => <String, Object?>{'status': 'notFound'};

      expect(
        await VolumeChannel().eject('/Volumes/GONE'),
        isA<EjectVolumeNotFound>(),
      );
    });

    test('turns a platform exception into a refusal instead of throwing', () async {
      messenger.setMockMethodCallHandler(method, (call) async {
        throw PlatformException(code: 'EJECT_FAILED', message: 'session unavailable');
      });

      final outcome = await VolumeChannel().eject('/Volumes/LEICA Q3');

      expect((outcome as EjectRefused).message, contains('session unavailable'));
    });
  });

  group('mount watching', () {
    void emit(Map<String, Object?> event) {
      ServicesBinding.instance.channelBuffers.push(
        VolumeChannel.eventChannelName,
        codec.encodeSuccessEnvelope(event),
        (_) {},
      );
    }

    test('turns notifications into typed events', () async {
      messenger.setMockMethodCallHandler(events, (call) async => null);

      final seen = <VolumeEvent>[];
      final subscription = VolumeChannel().watchVolumes().listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      emit({'kind': 'mounted', 'path': '/Volumes/LEICA Q3', 'name': 'LEICA Q3'});
      emit({'kind': 'willUnmount', 'path': '/Volumes/LEICA Q3'});
      emit({'kind': 'unmounted', 'path': '/Volumes/LEICA Q3'});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(seen.map((e) => e.kind), [
        VolumeEventKind.mounted,
        VolumeEventKind.willUnmount,
        VolumeEventKind.unmounted,
      ]);
      expect(seen.first.name, 'LEICA Q3');
    });

    test('drops a notification kind it does not model', () async {
      messenger.setMockMethodCallHandler(events, (call) async => null);

      final seen = <VolumeEvent>[];
      final subscription = VolumeChannel().watchVolumes().listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      emit({'kind': 'renamed', 'path': '/Volumes/LEICA Q3'});
      emit({'kind': 'unmounted', 'path': '/Volumes/LEICA Q3'});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      // Folding an unknown kind into a default would announce a card removal
      // that never happened, and halt work on a card that is still present.
      expect(seen.map((e) => e.kind), [VolumeEventKind.unmounted]);
    });
  });
}

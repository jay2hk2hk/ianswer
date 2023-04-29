import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'OKEY', obfuscate: true)
  static final oApiKey = _Env.oApiKey;
}

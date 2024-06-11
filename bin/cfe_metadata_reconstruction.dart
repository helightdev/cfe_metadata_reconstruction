import 'package:args/args.dart';
import 'package:cfe_metadata_reconstruction/macro.dart';

void main(List<String> arguments) {
  for (var obj in TestClass.objects) {
    print(obj.annotations);
  }
}

@TestMacro()
class TestClass {

  @TestAnnotation("Value!")
  void testMethod() {}

}

class TestAnnotation {
  final String name;
  const TestAnnotation(this.name);
}
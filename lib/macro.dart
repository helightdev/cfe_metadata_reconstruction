import 'dart:async';
import 'package:macros/macros.dart';


final _dartCore = Uri.parse('dart:core');
final _self = Uri.parse('package:cfe_metadata_reconstruction/macro.dart');

macro class TestMacro implements ClassDeclarationsMacro, ClassDefinitionMacro {

  const TestMacro();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    var [dartList, generatedObjectDef, overrideAnnotation] = await builder.resolveMany([
      (_dartCore, 'List'),
      (_self, 'GeneratedObject'),
      (_dartCore, 'override')
    ]);

    builder.declareInType(DeclarationCode.fromParts([
      "external static ",
      NamedTypeAnnotationCode(name: dartList, typeArguments: [NamedTypeAnnotationCode(name: generatedObjectDef)]),
      " get objects;"
    ]));
  }

  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {
    var [dartList, dartObject, generateObjectDef] = await builder.resolveMany([
      (_dartCore, 'List'),
      (_dartCore, 'Object'),
      (_self, 'GeneratedObject'),
    ]);

    List<Code> routes = [];
    for (var method in await builder.methodsOf(clazz)) {
      routes.add(RawCode.fromParts([
        NamedTypeAnnotationCode(name: generateObjectDef),
        "(",
        await createMetaList(method.metadata, builder),
        ")"
      ]));
    }

    var objectsGetter = await builder.methodsOf(clazz).then((methods) =>
        methods.firstWhere((element) =>
        element.identifier.name == 'objects' && element.isGetter));

    var routesBuilder = await builder.buildMethod(objectsGetter.identifier);
    routesBuilder.augment(FunctionBodyCode.fromParts([
      "=> [",
      ...routes.commaDelimited,
      "];"
    ]));
  }
}


class GeneratedObject {
  final List<Object> annotations;
  GeneratedObject(this.annotations);
}

extension BuilderExtension on TypePhaseIntrospector {
  Future<List<Identifier>> resolveMany(List<(Uri, String)> args) async {
    return await Future.wait(args.map((e) => resolveIdentifier(e.$1, e.$2)));
  }
}

extension MacroIterableExtension<T extends Object> on Iterable<T> {
  List<Object> get commaDelimited {
    if (isEmpty) return [];
    return expand((e) => [e, ","]).skipLast(1).toList();
  }

  List<T> skipLast(int n) {
    var list = toList();
    if (n == 0) return list;
    if (n >= list.length) return [];
    return list.sublist(0, list.length - n);
  }

  List<Object> get simplifyParts {
    return expand<Object>((e) {
      return switch (e) {
        Iterable<Object>() => e.simplifyParts,
        Code() => [e],
        String() => [e],
        Identifier() => [e],
        Object() => [e.toString()],
      };
    }).toList();
  }

  Future<T?> firstOfStaticType(TypeAnnotation Function(T) selector,
      DeclarationPhaseIntrospector builder, Identifier searched) async {
    var annotation = NamedTypeAnnotationCode(name: searched);
    var searchedType = await builder.resolve(annotation);
    for (var element in this) {
      var type = selector(element);
      if (type is! NamedTypeAnnotation) continue;
      var otherType = await builder.resolve(type.code);
      if (await otherType.isSubtypeOf(searchedType)) {
        return element;
      }
    }
    return null;
  }
}

Code recreateAnnotation(MetadataAnnotation annotation) {
  if (annotation is ConstructorMetadataAnnotation) {
    var parts = <Object>[annotation.type.code, "("];
    for (var arg in annotation.positionalArguments) {
      parts.add(arg);
      parts.add(",");
    }
    for (var arg in annotation.namedArguments.entries) {
      parts.add(arg.key);
      parts.add(":");
      parts.add(arg.value);
      parts.add(",");
    }
    parts.add(")");
    return RawCode.fromParts(parts);
  } else if (annotation is IdentifierMetadataAnnotation) {
    return NamedTypeAnnotationCode(name: annotation.identifier);
  }

  throw ArgumentError.value(annotation, 'annotation', 'Unsupported annotation');
}

Future<Code> createMetaList(Iterable<MetadataAnnotation> metadata, DefinitionBuilder builder) async {
  var parts = <Object>["["];
  for (var meta in metadata) {
    if (meta is ConstructorMetadataAnnotation) {
      var type = await builder.resolve(meta.type.code);
      parts.add(recreateAnnotation(meta));
      parts.add(",");
    } else if (meta is IdentifierMetadataAnnotation) {
      var dec = await builder.declarationOf(meta.identifier);
      if (dec is FunctionDeclaration) {
        parts.add(recreateAnnotation(meta));
        parts.add(",");
      }
    }
  }
  parts.add("]");
  return RawCode.fromParts(parts);
}
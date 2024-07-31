import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';
import 'dart:typed_data';
import 'package:three_js_core/three_js_core.dart';
import 'package:three_js_math/three_js_math.dart';
import 'dart:math';
import 'dart:ui';

List<String> getTriangleDefinitions(List<Triangle> triangles) {
  String getVectorDefinition(Vector3 v) {
    return 'new THREE.Vector(${v.x},${v.y},${v.z})';
  }

  return triangles.map((t) {
    return ''' new THREE.Triangle(${getVectorDefinition(t.a)},${getVectorDefinition(t.b)},${getVectorDefinition(t.c)},)''';
  }).toList();
}

void logTriangleDefinitions(List<Triangle> triangles) {
  printToConsole(getTriangleDefinitions(triangles).join(',\n'));
}

void generateRandomTriangleColors(BufferGeometry geometry) {
  //const position = geometry.attributes.position
  var position = geometry.attributes['position'];
  var array = Float32List(position.count * 3);

  var color = Color();
  for (var i = 0, l = array.length; i < l; i += 9) {
    color.setHSL(Random().nextDouble(), lerpDouble(0.5, 1.0, Random().nextDouble())!,
        lerpDouble(0.5, 0.75, Random().nextDouble())!);

    array[i + 0] = color.red;
    array[i + 1] = color.green;
    array[i + 2] = color.blue;

    array[i + 3] = color.red;
    array[i + 4] = color.green;
    array[i + 5] = color.blue;

    array[i + 6] = color.red;
    array[i + 7] = color.green;
    array[i + 8] = color.blue;
  }

  //geometry.setAttribute( 'color', new BufferAttribute( array, 3 ) );
  geometry.setAttribute('color' as Attribute, (array, 3) as BufferAttribute);
}

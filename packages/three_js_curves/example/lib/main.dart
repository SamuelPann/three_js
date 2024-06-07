import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_text/three_js_text.dart';
import 'package:three_js_math/three_js_math.dart' as tmath;
import 'package:three_js_curves/three_js_curves.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WebglGeometryExtrudeShapes(),
    );
  }
}


class WebglGeometryExtrudeShapes extends StatefulWidget {
  const WebglGeometryExtrudeShapes({super.key});

  @override
  createState() => _State();
}

class _State extends State<WebglGeometryExtrudeShapes> {
  late three.ThreeJS threeJs;

  @override
  void initState() {
    threeJs = three.ThreeJS(
      onSetupComplete: (){setState(() {});},
      setup: setup,
    );
    super.initState();
  }
  @override
  void dispose() {
    threeJs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return threeJs.build();
  }

  Future<void> setup() async {
    threeJs.scene = three.Scene();
    threeJs.scene.background = tmath.Color.fromHex32( 0x222222 );

    threeJs.camera = three.PerspectiveCamera( 45, threeJs.width/threeJs.height, 1, 1000 );
    threeJs.camera.position.setValues( 0, 0, 500 );

    threeJs.scene.add( three.AmbientLight( 0x666666 ) );

    final light = three.PointLight( 0xffffff, 0.9, 0, 0 );
    light.position.setFrom( threeJs.camera.position );
    threeJs.scene.add( light );

    final closedSpline = CatmullRomCurve3( points: [
      tmath.Vector3( - 60, - 100, 60 ),
      tmath.Vector3( - 60, 20, 60 ),
      tmath.Vector3( - 60, 120, 60 ),
      tmath.Vector3( 60, 20, - 60 ),
      tmath.Vector3( 60, - 100, - 60 )
    ] );

    closedSpline.curveType = 'catmullrom';
    closedSpline.closed = true;

    final ExtrudeGeometryOptions extrudeSettings1 = ExtrudeGeometryOptions(
      steps: 100,
      bevelEnabled: false,
      extrudePath: closedSpline
    );


    final List<tmath.Vector2> pts1 = [];
    const count = 3;

    for ( int i = 0; i < count; i ++ ) {
      const l = 20;
      final a = 2 * i / count * math.pi;
      pts1.add( tmath.Vector2( math.cos( a ) * l, math.sin( a ) * l ) );
    }

    final shape1 = Shape( pts1 );
    final geometry1 = ExtrudeGeometry( [shape1], extrudeSettings1 );
    final material1 = three.MeshLambertMaterial.fromMap( { 'color': 0xb00000, 'wireframe': false } );
    final mesh1 = three.Mesh( geometry1, material1 );

    mesh1.castShadow = true;
    mesh1.receiveShadow = true;
    threeJs.scene.add( mesh1 );

    final List<tmath.Vector3> randomPoints = [];

    for (int i = 0; i < 10; i ++ ) {
      randomPoints.add( 
        tmath.Vector3( ( i - 4.5 ) * 50, -50 + math.Random().nextDouble() * (50 - -50), -50 + math.Random().nextDouble() * (50 - -50) ) );
    }

    final randomSpline = CatmullRomCurve3(points: randomPoints );

    //

    final ExtrudeGeometryOptions extrudeSettings2 = ExtrudeGeometryOptions(
      steps: 200,
      bevelEnabled: false,
      extrudePath: randomSpline
    );


    final List<tmath.Vector2> pts2 = [];
    const numPts = 5;

    for ( int i = 0; i < numPts * 2; i ++ ) {
      final l = i % 2 == 1 ? 10 : 20;
      final a = i / numPts * math.pi;
      pts2.add( tmath.Vector2( math.cos( a ) * l, math.sin( a ) * l ) );
    }

    final shape2 = Shape(pts2 );
    final geometry2 = ExtrudeGeometry( [shape2], extrudeSettings2 );
    final material2 = three.MeshLambertMaterial.fromMap( { 'color': 0xff8000, 'wireframe': false } );
    final mesh2 = three.Mesh( geometry2, material2 );

    threeJs.scene.add( mesh2 );


    final materials = three.GroupMaterial([ material1, material2 ]);

    final ExtrudeGeometryOptions extrudeSettings3 = ExtrudeGeometryOptions(
      depth: 20,
      steps: 1,
      bevelEnabled: true,
      bevelThickness: 2,
      bevelSize: 4,
      bevelSegments: 1
    );

    final geometry3 = ExtrudeGeometry( [shape2], extrudeSettings3 );
    final mesh3 = three.Mesh( geometry3, materials );
    mesh3.position.setValues( 50, 100, 50 );
    threeJs.scene.add( mesh3 );
  }
}
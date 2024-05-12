import 'dart:async';
import 'dart:math' as math;
import 'package:example/src/demo.dart';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_geometry/three_js_geometry.dart';

class WebglGeometries extends StatefulWidget {
  final String fileName;
  const WebglGeometries({super.key, required this.fileName});

  @override
  createState() => _State();
}

class _State extends State<WebglGeometries> {
  late Demo demo;

  @override
  void initState() {
    demo = Demo(
      fileName: widget.fileName,
      onSetupComplete: (){setState(() {});},
      setup: setup,
      settings: DemoSettings(
        localClippingEnabled: true
      )
    );
    super.initState();
  }
  @override
  void dispose() {
    demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return demo.threeDart();
  }

  int startTime = 0;

  Future<void> setup() async {
    demo.camera = three.PerspectiveCamera(45, demo.width / demo.height, 1, 2000);
    demo.camera.position.y = 400;

    demo.scene = three.Scene();

    three.Mesh object;

    final ambientLight = three.AmbientLight(0xcccccc, 0.4);
    demo.scene.add(ambientLight);

    final pointLight = three.PointLight(0xffffff, 0.8);
    demo.camera.add(pointLight);
    demo.scene.add(demo.camera);

    final loader = three.TextureLoader();
    final map = await loader.fromAsset('assets/textures/uv_grid_opengl.jpg');
    map?.wrapS = map.wrapT = three.RepeatWrapping;
    map?.anisotropy = 16;

    final material = three.MeshPhongMaterial.fromMap({"map": map, "side": three.DoubleSide});

    //

    object = three.Mesh(three.SphereGeometry(75, 20, 10), material);
    object.position.setValues(-300, 0, 200);
    demo.scene.add(object);

    object = three.Mesh(IcosahedronGeometry(75, 1), material);
    object.position.setValues(-100, 0, 200);
    demo.scene.add(object);

    object = three.Mesh(OctahedronGeometry(75, 2), material);
    object.position.setValues(100, 0, 200);
    demo.scene.add(object);

    object = three.Mesh(TetrahedronGeometry(75, 0), material);
    object.position.setValues(300, 0, 200);
    demo.scene.add(object);

    //

    object = three.Mesh(three.PlaneGeometry(100, 100, 4, 4), material);
    object.position.setValues(-300, 0, 0);
    demo.scene.add(object);

    object = three.Mesh(three.BoxGeometry(100, 100, 100, 4, 4, 4), material);
    object.position.setValues(-100, 0, 0);
    demo.scene.add(object);

    object = three.Mesh(
        CircleGeometry(
            radius: 50,
            segments: 20,
            thetaStart: 0,
            thetaLength: math.pi * 2),
        material);
    object.position.setValues(100, 0, 0);
    demo.scene.add(object);

    object = three.Mesh(RingGeometry(10, 50, 20, 5, 0, math.pi * 2), material);
    object.position.setValues(300, 0, 0);
    demo.scene.add(object);

    //

    object = three.Mesh(CylinderGeometry(25, 75, 100, 40, 5), material);
    object.position.setValues(-300, 0, -200);
    demo.scene.add(object);

    List<three.Vector2> points = [];

    for (int i = 0; i < 50; i++) {
      points.add(three.Vector2(
          math.sin(i * 0.2) * math.sin(i * 0.1) * 15 + 50,
          (i - 5) * 2));
    }

    object = three.Mesh(LatheGeometry(points, segments: 20), material);
    object.position.setValues(-100, 0, -200);
    demo.scene.add(object);

    object = three.Mesh(TorusGeometry(50, 20, 20, 20), material);
    object.position.setValues(100, 0, -200);
    demo.scene.add(object);

    object = three.Mesh(TorusKnotGeometry(50, 10, 50, 20), material);
    object.position.setValues(300, 0, -200);
    demo.scene.add(object);

    startTime = DateTime.now().millisecondsSinceEpoch;

    demo.addAnimationEvent((dt){
      final timer = DateTime.now().millisecondsSinceEpoch * 0.0001;

      demo.camera.position.x = math.cos(timer) * 800;
      demo.camera.position.z = math.sin(timer) * 800;
      demo.camera.lookAt(demo.scene.position);

      demo.scene.traverse((object) {
        if (object is three.Mesh) {
          object.rotation.x = timer * 5;
          object.rotation.y = timer * 2.5;
        }
      });
    });
  }
}

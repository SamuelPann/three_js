import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:css/css.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:three_js_editor/src/navigation/right_click.dart';
import 'package:three_js_editor/src/styles/savedWidgets.dart';

import 'package:three_js/three_js.dart' as three;
import 'package:three_js_helpers/three_js_helpers.dart';
import 'package:three_js_geometry/three_js_geometry.dart';
import 'package:three_js_transform_controls/three_js_transform_controls.dart';
import 'package:three_js_modifers/three_js_modifers.dart';
import 'package:three_js_objects/three_js_objects.dart';

import 'src/navigation/navigation.dart';
import 'src/database/filePicker.dart';
import 'src/styles/globals.dart';

enum ShadingType{wireframe,solid,material}
class GridInfo{
  int divisions = 10;
  double size = 10;
  int color = Colors.grey[900]!.value;
  double x = 0;
  double y = 0;
}
class IntersectsInfo{
  IntersectsInfo(this.intersects,this.oInt);
  List<three.Intersection> intersects = [];
  List<int> oInt = [];
}

class UIScreen extends StatefulWidget {
  const UIScreen({Key? key}):super(key: key);
  @override
  _UIPageState createState() => _UIPageState();
}

class _UIPageState extends State<UIScreen> {
  bool resetNav = false;
  late three.ThreeJS threeJs;

  three.Raycaster raycaster = three.Raycaster();
  three.Vector2 mousePosition = three.Vector2.zero();
  three.Object3D? intersected;
  bool didClick = false;
  bool usingMouse = false;

  late TransformControls control;
  late three.OrbitControls orbit;
  late three.PerspectiveCamera cameraPersp;
  late three.OrthographicCamera cameraOrtho;
  three.Group helper = three.Group();
  GridHelper grid = GridHelper( 500, 500, Colors.grey[900]!.value, Colors.grey[900]!.value);
  GridInfo gridInfo = GridInfo();

  three.Vector3 resetCamPos = three.Vector3(5, 2.5, 5);

  bool holdingControl = false;
  three.Object3D? copy;

  late RightClick rightClick;

  List<bool> expands = [false,false,false];
  List<TextEditingController> transfromControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];

  List<TextEditingController> modiferControllers = [
    TextEditingController(),
  ];
  bool subdivisionCC = true;

  bool throughSelected = false;
  ShadingType shading = ShadingType.solid;
  MarchingCubes? effect;
  three.Group mp = three.Group();
  three.TTFFont? font;
  double time = 0;

  @override
  void initState(){
    threeJs = three.ThreeJS(
      onSetupComplete: (){setState(() {});},
      setup: setup,
    );
    rightClick = RightClick(
      context: context,
      style: null,
      onTap: rightClickActions,
    );
    super.initState();
  }
  @override
  void dispose(){
    control.dispose();
    orbit.dispose();
    rightClick.dispose();
    threeJs.dispose();
    super.dispose();
  }
  void rightClickActions(RightClickOptions options){
    switch (options) {
      case RightClickOptions.delete:
        control.detach();
        threeJs.scene.remove(intersected!);
        intersected = null;
        break;
      case RightClickOptions.copy:
        copy = intersected;
        break;
      case RightClickOptions.paste:
        threeJs.scene.add(intersected);
        break;
      default:
    }
    rightClick.closeMenu();
    setState(() {});
  }

  static Future<void>? _writeToFile(String path, {String? spark, Uint8List? image}){
    final file = File(path);
    if(spark != null){
      return file.writeAsString(spark);
    }
    else if(image != null){
      return file.writeAsBytes(image);
    }
    return null;
  }

  Future<void> setup() async{
    const frustumSize = 5.0;
    final aspect = threeJs.width / threeJs.height;
    cameraPersp = three.PerspectiveCamera( 50, aspect, 0.1, 100 );
    cameraOrtho = three.OrthographicCamera( - frustumSize * aspect, frustumSize * aspect, frustumSize, - frustumSize, 0.1, 100 );
    threeJs.camera = cameraPersp;

    threeJs.camera.position.setFrom(resetCamPos);

    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(CSS.darkTheme.canvasColor.value);
    threeJs.scene.fog = three.Fog(CSS.darkTheme.canvasColor.value, 10,50);
    threeJs.scene.add( grid );

    final ambientLight = three.AmbientLight( 0xffffff, 0 );
    threeJs.scene.add( ambientLight );

    final light = three.DirectionalLight( 0xffffff, 0.5 );
    light.position = threeJs.camera.position;
    threeJs.scene.add( light );

    orbit = three.OrbitControls(threeJs.camera, threeJs.globalKey);
    orbit.update();

    control = TransformControls(threeJs.camera, threeJs.globalKey);

    control.addEventListener( 'dragging-changed', (event) {
      orbit.enabled = ! event.value;
    });
    creteHelpers();
    threeJs.scene.add( control );
    threeJs.scene.add(helper);

    threeJs.domElement.addEventListener(
      three.PeripheralType.resize, 
      threeJs.onWindowResize
    );
    threeJs.domElement.addEventListener(three.PeripheralType.keydown,(event) {
      event as LogicalKeyboardKey;
      //print(event.keyLabel.toLowerCase());
      switch (event.keyLabel.toLowerCase()) {
        case 'meta left':
          holdingControl = true;
        case 'q':
          control.setSpace( control.space == 'local' ? 'world' : 'local' );
          break;
        case 'shift right':
        case 'shift left':
          control.setTranslationSnap( 1 );
          control.setRotationSnap( three.MathUtils.degToRad( 15 ) );
          control.setScaleSnap( 0.25 );
          break;
        case 'w':
          control.setMode( 'translate' );
          break;
        case 'e':
          control.setMode( 'rotate' );
          break;
        case 'r':
          control.setMode( 'scale' );
          break;
        case 'c':
          if(holdingControl){
            copy = intersected;
          }
          break;
        case 'v':
          if(holdingControl){
            if(copy != null){
              threeJs.scene.add(copy?.clone());
            }
          }
          break;
        case '+':
        case '=':
          control.setSize( control.size + 0.1 );
          break;
        case '-':
        case '_':
          control.setSize( math.max( control.size - 0.1, 0.1 ) );
          break;
        case 'delete':
        case 'x':
          if(intersected != null){
            rightClick.openMenu('',Offset(mousePosition.x,mousePosition.y),[RightClickOptions.delete]);
          }
          break;
        // case 'tab':
        //   intersected?.material?.wireframe = intersected?.material?.wireframe != null? !intersected!.material!.wireframe:false;
        //   break;
        case 'y':
          break;
        case 'z':
          break;
        case ' ':
          break;
        case 'escape':
          break;
      }
    });
    threeJs.domElement.addEventListener(three.PeripheralType.keyup, (event) {
      event as LogicalKeyboardKey;
      switch ( event.keyLabel.toLowerCase() ) {
        case 'meta left':
          holdingControl = false;
        case 'shift right':
        case 'shift left':
          control.setTranslationSnap( null );
          control.setRotationSnap( null );
          control.setScaleSnap( null );
          break;
      }
    });
    threeJs.domElement.addEventListener(three.PeripheralType.pointerdown, (details){
      mousePosition = three.Vector2(details.clientX, details.clientY);
      if(threeJs.scene.children.length > 5 && !control.dragging){
        checkIntersection(threeJs.scene.children.sublist(5));
      }
    });
  }

  void creteHelpers(){
    List<double> vertices = [500,0,0,-500,0,0,0,0,500,0,0,-500];
    List<double> colors = [1,0,0,1,0,0,0,0,1,0,0,1];
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString('position',three.Float32BufferAttribute.fromList(vertices, 3, false));
    geometry.setAttributeFromString('color',three.Float32BufferAttribute.fromList(colors, 3, false));

    final material = three.LineBasicMaterial.fromMap({
      "vertexColors": true, 
      "toneMapped": true,
    })
      ..depthTest = false
      ..linewidth = 5.0
      ..depthWrite = true;

    helper.add(
      three.LineSegments(geometry,material)
      ..computeLineDistances()
      ..scale.setValues(1,1,1)
    );

  //   final scene = three.Scene();
  //   final camera = three.OrthographicCamera();
  //   camera.position.z = 10;
  //   final box = three.Mesh(three.BoxGeometry(),three.MeshPhongMaterial())
  //     ..quaternion = threeJs.camera.quaternion;

  //   scene.add(box);

  //   final control = TransformControls(threeJs.camera, threeJs.globalKey);
  //   control.
  //   control.addEventListener('change', (event) {
  //     threeJs.render();
  //   });

  //   control.addEventListener( 'dragging-changed', (event) {
  //     orbit.enabled = ! event.value;
  //   });
  //   scene.add( control );
  //   control.attach( box );
  //   threeJs.renderer?.autoClear = false;
  //   threeJs.postProcessor = ([double? dt]){
  //     threeJs.renderer!.setViewport(0,0,threeJs.width,threeJs.height);
  //     threeJs.renderer!.clear();
  //     threeJs.renderer!.render( threeJs.scene, threeJs.camera );
  //     threeJs.renderer!.clearDepth();
  //     threeJs.renderer!.render( scene, camera);
  //   };
  }

  three.Vector2 convertPosition(three.Vector2 location){
    double x = (location.x / (threeJs.width-MediaQuery.of(context).size.width/6)) * 2 - 1;
    double y = -(location.y / (threeJs.height-20)) * 2 + 1;
    return three.Vector2(x,y);
  }

  void callBacks({required LSICallbacks call}){
    switch (call) {
      case LSICallbacks.updatedNav:
        setState(() {
          resetNav = !resetNav;
        });
        break;
      case LSICallbacks.clear:
        setState(() {
          resetNav = !resetNav;
          if(threeJs.scene.children.length > 5){
            for(int i = 4; i < threeJs.scene.children.length;i++){
              threeJs.scene.children[i].dispose();
            }
            threeJs.scene.children.length = 5;
          }
        });
        break;
      case LSICallbacks.updateLevel:
        setState(() {

        });
        break;
      default:
    }
  }
  void materialWireframe(List<three.Object3D> objects, bool wireframe){
    for(final o in objects){
      if(o is! BoundingBoxHelper){
        o.material?.wireframe = wireframe;
        o.material?.colorWrite = true;
        materialWireframe(o.children,wireframe);
      }
    }
  }
  // void editMode(three.Object3D obj){
  //   editModes(List<three.Object3D> obj){
  //     for(final o in obj){
  //       if(o is! BoundingBoxHelper){
  //         o.material?.wireframe = wireframe;
  //         materialWireframe(o.children,wireframe);
  //       }
  //     }
  //   }
  //   List<three.Object3D> e = [];
  //   if(obj is three.BufferGeometry || obj is three.Mesh){
  //     e.add();
  //     editModes(obj.children);
  //   }
  // }
  IntersectsInfo getIntersections(List<three.Object3D> objects){
    IntersectsInfo ii = IntersectsInfo([], []);
    int i = 0;
    for(final o in objects){
      if(o is three.Group || o is three.AnimationObject || o.runtimeType == three.Object3D){
        final inter = getIntersections(o.children);
        ii.intersects.addAll(inter.intersects);
        ii.oInt.addAll(List.filled(inter.intersects.length, i));
      }
      else if(o is! three.Bone && o is! BoundingBoxHelper){
        final inter = raycaster.intersectObject(o, false);
        ii.intersects.addAll(inter);
        ii.oInt.addAll(List.filled(inter.length, i));
      }
      i++;
    }
    return ii;
  }
  void boxSelect(bool select){
    if(intersected == null) return;
    if(!select){
      control.detach();
      for(final o in intersected!.children){
        if(o is BoundingBoxHelper){
          o.visible = false;
        }
      }
    }
    else{
      for(final o in intersected!.children){
        if(o is BoundingBoxHelper){
          o.visible = true;
        }
      }
      control.attach( intersected );
    }
  }
  void checkIntersection(List<three.Object3D> objects) {
    IntersectsInfo ii = getIntersections(objects);
    raycaster.setFromCamera(convertPosition(mousePosition), threeJs.camera);

    if (ii.intersects.isNotEmpty ) {
      if(intersected != objects[ii.oInt[0]]) {
        if(intersected != null){
          boxSelect(false);
        }
        intersected = objects[ii.oInt[0]];
        boxSelect(true);
      }
    }
    else if(intersected != null){
      boxSelect(false);
      intersected = null;
    }

    if(didClick && intersected != null){

    }
    else if(didClick && ii.intersects.isEmpty){
      boxSelect(false);
      intersected = null;
    }

    didClick = false;
    setState(() {

    });
  }
  Widget intersectedData(){
    return ListView(
      children: [
        Container(
          //height: MediaQuery.of(context).size.height - MediaQuery.of(context).size.height/3 - 40,
          margin: const EdgeInsets.fromLTRB(5,5,5,5),
          decoration: BoxDecoration(
            color: CSS.darkTheme.cardColor,
            borderRadius: BorderRadius.circular(5)
          ),
          child: Column(
            children: [
              InkWell(
                onTap: (){
                  setState(() {
                    expands[0] = !expands[0];
                  });
                },
                child: Row(
                  children: [
                    Icon(!expands[0]?Icons.expand_more:Icons.expand_less, size: 15,),
                    const Text('\tTransform'),
                  ],
                )
              ),
              if(expands[0]) Padding(
                padding: const EdgeInsets.fromLTRB(25,10,5,5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location'),
                    const SizedBox(height: 5,),
                    Row(
                      children: [
                        const Text('X'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.position.x.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.position.x = double.parse(val);
                          },
                          controller: transfromControllers[0],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Y'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.position.y.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.position.y = double.parse(val);
                          },
                          controller: transfromControllers[1],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Z'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.position.z.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.position.z = double.parse(val);
                          },
                          controller: transfromControllers[2],
                        )
                      ],
                    ),

                    const SizedBox(height: 10,),
                    const Text('Rotate'),
                    const SizedBox(height: 5,),
                    Row(
                      children: [
                        const Text('X'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.rotation.x.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.rotation.x = double.parse(val);
                          },
                          controller: transfromControllers[3],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Y'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.rotation.y.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.rotation.y = double.parse(val);
                          },
                          controller: transfromControllers[4],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Z'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.rotation.z.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.rotation.z = double.parse(val);
                          },
                          controller: transfromControllers[5],
                        )
                      ],
                    ),

                    const SizedBox(height: 10,),
                    const Text('Scale'),
                    const SizedBox(height: 5,),
                    Row(
                      children: [
                        const Text('X'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.scale.x.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.scale.x = double.parse(val);
                          },
                          controller: transfromControllers[6],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Y'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.scale.y.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.scale.y = double.parse(val);
                          },
                          controller: transfromControllers[7],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Z'),
                        EnterTextFormField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          label: intersected!.scale.z.toString(),
                          width: 80,
                          height: 20,
                          maxLines: 1,
                          textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                          color: Theme.of(context).canvasColor,
                          onChanged: (val){
                            intersected!.scale.z = double.parse(val);
                          },
                          controller: transfromControllers[8],
                        )
                      ],
                    )
                  ],
                )
              )
            ],
          ),
        ),
        Container(
          //height: MediaQuery.of(context).size.height - MediaQuery.of(context).size.height/3 - 40,
          margin: const EdgeInsets.fromLTRB(5,5,5,5),
          decoration: BoxDecoration(
            color: CSS.darkTheme.cardColor,
            borderRadius: BorderRadius.circular(5)
          ),
          child: Column(
            children: [
              InkWell(
                onTap: (){
                  setState(() {
                    expands[1] = !expands[1];
                  });
                },
                child: Row(
                  children: [
                    Icon(!expands[1]?Icons.expand_more:Icons.expand_less, size: 15,),
                    const Text('\tMaterial'),
                  ],
                )
              ),
              if(expands[1]) Padding(
                padding: const EdgeInsets.fromLTRB(25,10,5,5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                  ]
                )
              )
            ]
          )
        ),
        Container(
          //height: MediaQuery.of(context).size.height - MediaQuery.of(context).size.height/3 - 40,
          margin: const EdgeInsets.fromLTRB(5,5,5,5),
          decoration: BoxDecoration(
            color: CSS.darkTheme.cardColor,
            borderRadius: BorderRadius.circular(5)
          ),
          child: Column(
            children: [
              InkWell(
                onTap: (){
                  setState(() {
                    expands[2] = !expands[2];
                  });
                },
                child: Row(
                  children: [
                    Icon(!expands[2]?Icons.expand_more:Icons.expand_less, size: 15,),
                    const Text('\t Modifer'),
                  ],
                )
              ),
              if(expands[2]) Padding(
                padding: const EdgeInsets.fromLTRB(5,5,5,5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      //height: MediaQuery.of(context).size.height - MediaQuery.of(context).size.height/3 - 40,
                      margin: const EdgeInsets.fromLTRB(5,5,5,5),
                      decoration: BoxDecoration(
                        color: CSS.darkTheme.cardColor,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: CSS.darkTheme.secondaryHeaderColor)
                      ),
                      child: Column(
                        children: [
                          const Text('Subdivision'),
  
                          InkWell(
                            onTap: (){
                              setState(() {
                                subdivisionCC = !subdivisionCC;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(5),
                              padding: const EdgeInsets.all(5),
                              height: 30,
                              width: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: CSS.darkTheme.canvasColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(5),
                                  bottomLeft: Radius.circular(5)
                                ),
                                //border: Border.all(color: CSS.darkTheme.secondaryHeaderColor)
                              ),
                              child: Text(subdivisionCC?'Catmull-Clark':'Simple'),
                            ),
                          ),
             
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Levels: '),
                              InkWell(
                                onTap: (){
                                  setState(() {
                                    if(intersected!.userData['subdivisions'] != null && intersected!.userData['subdivisions'] > 0){
                                      intersected!.userData['subdivisions'] -= 1;
                                    }
                                    else if(intersected!.userData['subdivisions'] == null){
                                      intersected!.userData['subdivisions'] = 0;
                                    }

                                  });
                                },
                                child: Icon(Icons.arrow_back_ios_new_rounded,size:10),
                              ),
                              EnterTextFormField(
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                label: (intersected!.userData['subdivisions'] ?? 0).toString(),
                                width: 50,
                                height: 20,
                                maxLines: 1,
                                margin: const EdgeInsets.all(0),
                                textStyle: Theme.of(context).primaryTextTheme.bodySmall,
                                color: Theme.of(context).canvasColor,
                                onChanged: (val){
                                  intersected!.userData['subdivisions'] = val;
                                },
                                controller: modiferControllers[0],
                              ),
                              InkWell(
                                onTap: (){
                                  setState(() {
                                    if(intersected!.userData['subdivisions'] != null){
                                      intersected!.userData['subdivisions'] += 1;
                                    }
                                    else if(intersected!.userData['subdivisions'] == null){
                                      intersected!.userData['subdivisions'] = 1;
                                    }

                                    final smoothGeometry = LoopSubdivision.modify(
                                      intersected!.geometry!, 
                                      intersected!.userData['subdivisions'], 
                                      LoopParameters.fromJson({
                                        'split': true,
                                        'uvSmooth': false,
                                        'preserveEdges': false,
                                        'flatOnly': !subdivisionCC,
                                      })
                                    );

                                    intersected!.geometry = smoothGeometry;
                                  });
                                },
                                child: Icon(Icons.arrow_forward_ios_rounded,size:10),
                              )
                            ],
                          )
                        ],
                      )
                    )
                  ]
                )
              )
            ]
          )
        )
      ],
    );
  }
  Widget sceneCollection(){
    List<Widget> widgets = [
      Container(
        margin: const EdgeInsets.fromLTRB(5, 0, 5, 0),
        height: 25,
        child: const Row(
          //mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.inventory ,size: 15,),
            Text('\tScene Collection'),
          ],
        ),
      ) 
    ];

    for(int i = 5; i < threeJs.scene.children.length; i++){
      final child = threeJs.scene.children[i];
      widgets.add(
        InkWell(
          onTap: (){
            boxSelect(false);
            intersected = child;
            boxSelect(true);
            setState(() {
              
            });
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(5, 0, 5, 0),
            padding: const EdgeInsets.fromLTRB(15, 0, 5, 0),
            height: 25,
            color: child == intersected?CSS.darkTheme.secondaryHeaderColor:CSS.darkTheme.canvasColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(child.name),
                InkWell(
                  onTap: (){
                    setState(() {
                      child.visible = !child.visible;
                    });
                  },
                  child: Icon(child.visible?Icons.visibility:Icons.visibility_off,size: 15,),
                )
              ],
            ),
          )
        )
      );
    } 

    return ListView(
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    deviceWidth = MediaQuery.of(context).size.width;
    double safePadding = MediaQuery.of(context).padding.top;
    deviceHeight = MediaQuery.of(context).size.height-safePadding-25;

    return MaterialApp(
      theme: CSS.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size(deviceWidth,50), 
          child:Navigation(
            height: 25,
            callback: callBacks,
            reset: resetNav,
            navData: [
                NavItems(
                  name: 'File',
                  subItems:[ 
                    NavItems(
                      name: 'New',
                      icon: Icons.new_label_outlined,
                      function: (data){
                        callBacks(call: LSICallbacks.clear);
                      }
                    ),
                    NavItems(
                      name: 'Open',
                      icon: Icons.folder_open,
                      function: (data){
                        setState(() {
                          callBacks(call: LSICallbacks.clear);
                          GetFilePicker.pickFiles(['spark','jle']).then((value)async{
                            if(value != null){
                              for(int i = 0; i < value.files.length;i++){

                              }
                            }
                          });
                        });
                      }
                    ),
                    NavItems(
                      name: 'Save',
                      icon: Icons.save,
                      function: (data){
                        callBacks(call: LSICallbacks.updatedNav);
                        setState(() {

                        });
                      }
                    ),
                    NavItems(
                      name: 'Save As',
                      icon: Icons.save_outlined,
                      function: (data){
                        setState(() {
                          callBacks(call: LSICallbacks.updatedNav);
                          if(!kIsWeb){
                            GetFilePicker.saveFile('untilted', 'jle').then((path){
                              setState(() {

                              });
                            });
                          }
                          else if(kIsWeb){
                          }
                        });
                      }
                    ),
                    NavItems(
                      name: 'Import',
                      icon: Icons.file_download_outlined,
                      subItems: [
                        NavItems(
                          name: 'obj',
                          icon: Icons.view_in_ar_rounded,
                          function: (data) async{
                            callBacks(call: LSICallbacks.updatedNav);
                            final manager = three.LoadingManager();
                            three.MaterialCreator? materials;
                            final objs = await GetFilePicker.pickFiles(['obj']);
                            final mtls = await GetFilePicker.pickFiles(['mtl']);
                            if(mtls != null){
                              for(int i = 0; i < mtls.files.length;i++){
                                final mtlLoader = three.MTLLoader(manager);
                                final last = mtls.files[i].path!.split('/').last;
                                mtlLoader.setPath(mtls.files[i].path!.replaceAll(last,''));
                                materials = await mtlLoader.fromPath(last);
                                await materials?.preload();
                              }
                            }
                            if(objs != null){
                              for(int i = 0; i < objs.files.length;i++){
                                final loader = three.OBJLoader();
                                loader.setMaterials(materials);
                                final object = await loader.fromPath(objs.files[i].path!);
                                final three.BoundingBox box = three.BoundingBox();
                                box.setFromObject(object!);
                                object.scale = three.Vector3(0.01,0.01,0.01);        
                                BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                object.name = objs.files[i].name.split('.').first;
                                threeJs.scene.add(object.add(h));
                              }
                            }
                            setState(() {});
                          },
                        ),
                        NavItems(
                          name: 'stl',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            GetFilePicker.pickFiles(['stl']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final object = await three.STLLoader().fromPath(value.files[i].path!);
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object!);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.name = value.files[i].name.split('.').first;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                              setState(() {});
                            });
                          },
                        ),
                        NavItems(
                          name: 'ply',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            GetFilePicker.pickFiles(['ply']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final buffer = await three.PLYLoader().fromPath(value.files[i].path!);
                                  final object = three.Mesh(buffer,three.MeshPhongMaterial());
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object);
                                  object.scale = three.Vector3(0.01,0.01,0.01);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.name = value.files[i].name.split('.').first;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                              setState(() {});
                            });
                          },
                        ),
                        NavItems(
                          name: 'glb/gltf',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            GetFilePicker.pickFiles(['glb','gltf']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final object = await three.GLTFLoader().fromPath(value.files[i].path!);
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object!.scene);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.scene.name = value.files[i].name.split('.').first;
                                  threeJs.scene.add(object.scene.add(h));
                                }
                              }
                              setState(() {});
                            });
                          },
                        ),
                        NavItems(
                          name: 'fbx',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            setState(() {

                            });
                            GetFilePicker.pickFiles(['fbx']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final object = await three.FBXLoader(width: 1,height: 1).fromPath(value.files[i].path!);
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object!);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.scale = three.Vector3(0.01,0.01,0.01);
                                  object.name = value.files[i].name;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                            });
                          },
                        ),
                        NavItems(
                          name: 'usdz',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            setState(() {

                            });
                            GetFilePicker.pickFiles(['usdz']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final object = await three.USDZLoader().fromPath(value.files[i].path!);
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object!);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.scale = three.Vector3(0.01,0.01,0.01);
                                  object.name = value.files[i].name;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                            });
                          },
                        ),
                        NavItems(
                          name: 'collada',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            setState(() {

                            });
                            GetFilePicker.pickFiles(['dae']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final mesh = await three.ColladaLoader().fromPath(value.files[i].path!);
                                  final object = mesh!.scene!;
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.name = value.files[i].name;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                            });
                          },
                        ),
                        NavItems(
                          name: 'xyz',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            setState(() {

                            });
                            GetFilePicker.pickFiles(['xyz']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final mesh = await three.XYZLoader().fromPath(value.files[i].path!);
                                  final object = three.Mesh(mesh,three.MeshPhongMaterial());
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.name = value.files[i].name;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                            });
                          },
                        ),
                        NavItems(
                          name: 'vox',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            setState(() {

                            });
                            GetFilePicker.pickFiles(['vox']).then((value)async{
                              if(value != null){
                                for(int i = 0; i < value.files.length;i++){
                                  final chunks = await three.VOXLoader().fromPath(value.files[i].path!);
                                  final object = three.Group();
                                  for (int i = 0; i < chunks!.length; i ++ ) {
                                    final chunk = chunks[ i ];
                                    final mesh = three.VOXMesh( chunk );
                                    mesh.scale.setScalar( 0.0015 );
                                    object.add( mesh );
                                  }
                                  final three.BoundingBox box = three.BoundingBox();
                                  box.setFromObject(object);
                                  BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                                  object.name = value.files[i].name;
                                  threeJs.scene.add(object.add(h));
                                }
                              }
                            });
                          },
                        ),
                      ]
                    ),
                    NavItems(
                      name: 'Export',
                      icon: Icons.file_upload_outlined,
                      subItems: [
                        NavItems(
                          name: 'json',
                          icon: Icons.file_copy_outlined,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            GetFilePicker.saveFile('untilted', 'json').then((path){

                            });
                          }
                        ),
                        NavItems(
                          name: 'level image',
                          icon: Icons.image,
                          function: (data){
                            setState(() {
                              callBacks(call: LSICallbacks.updatedNav);
                              GetFilePicker.saveFile('untilted', 'png').then((path){

                              });
                            });
                          }
                        )
                      ]
                    ),
                    NavItems(
                      name: 'Quit',
                      icon: Icons.exit_to_app,
                      function: (data){
                        callBacks(call: LSICallbacks.updatedNav);
                        SystemNavigator.pop();
                      }
                    ),
                  ]
                ),
                NavItems(
                  name: 'View',
                  subItems:[
                    NavItems(
                      name: 'Reset Camera',
                      icon: Icons.camera_indoor_outlined,
                      function: (e){
                        callBacks(call: LSICallbacks.updatedNav);
                        threeJs.camera.position.setFrom(resetCamPos);
                      }
                    )
                  ]
                ),
                NavItems(
                  name: 'Add',
                  subItems:[ 
                    NavItems(
                      name: 'Mesh',
                      icon: Icons.share,
                      subItems: [
                        NavItems(
                          name: 'Plane',
                          icon: Icons.view_in_ar_rounded,
                          function: (data) async{
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(three.PlaneGeometry(),three.MeshStandardMaterial.fromMap({'side': three.DoubleSide, 'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Plane';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Cube',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(three.BoxGeometry(),three.MeshStandardMaterial.fromMap({'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.receiveShadow = true;
                            object.name = 'Cube';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Circle',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(CircleGeometry(),three.MeshStandardMaterial.fromMap({'side': three.DoubleSide, 'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Circle';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Sphere',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(three.SphereGeometry(),three.MeshStandardMaterial.fromMap({'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Sphere';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Ico Sphere',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(IcosahedronGeometry(),three.MeshStandardMaterial.fromMap({'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Ico Sphere';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Cylinder',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(CylinderGeometry(),three.MeshStandardMaterial.fromMap({'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Cylinder';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Cone',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(ConeGeometry(),three.MeshStandardMaterial.fromMap({'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Cone';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                        NavItems(
                          name: 'Torus',
                          icon: Icons.view_in_ar_rounded,
                          function: (data){
                            callBacks(call: LSICallbacks.updatedNav);
                            final object = three.Mesh(TorusGeometry(),three.MeshStandardMaterial.fromMap({'flatShading': true}));
                            final three.BoundingBox box = three.BoundingBox();
                            box.setFromObject(object);     
                            BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                            object.name = 'Torus';
                            threeJs.scene.add(object.add(h));
                          },
                        ),
                      ]
                    ),
                    NavItems(
                      name: 'Metaball',
                      icon: Icons.view_in_ar_rounded,
                      function: (e){
                        if(effect == null){
                          effect = MarchingCubes(28, three.MeshStandardMaterial.fromMap({'flatShading': true}), true, true, 100000 );
                          effect!.position.setValues( 0, 0, 0 );
                          effect!.scale.setValues( 1, 1, 1 );

                          effect!.enableUvs = false;
                          effect!.enableColors = false;
                          effect!.name = 'MarchingCubes';
                          
                          threeJs.scene.add(mp);
                          threeJs.scene.add( effect! );
                        }
                        final b = three.BufferGeometry();
                        List<double> v = [0.5,0.5,0.5];
                        b.setAttributeFromString('position',three.Float32BufferAttribute.fromList(v, 3, false));

                        mp.add(three.Points(b,three.MeshStandardMaterial())..name = 'Metaball');
                        effect?.addBall(v[0],v[1],v[2], 1, 1);
                        effect?.update();

                        setState(() {});
                      }
                    ),
                    NavItems(
                      name: 'Text',
                      icon: Icons.view_in_ar_rounded,
                      function: (e) async{
                        if(font == null){
                          final loader = three.FontLoader();
                          font = await loader.fromAsset( 'assets/helvetiker_bold.typeface.json');
                        }
                        final text = three.TextGeometry( 'Text', three.TextGeometryOptions(
                          font: font,
                          size: 50,
                          depth: 0,
                          curveSegments: 10,
                          bevelThickness: 5,
                          bevelSize: 1.5,
                          bevelEnabled: true,
                          bevelSegments: 10,
                        ));
                        final obj = three.Mesh(text,three.MeshPhongMaterial.fromMap({'flatShading': true}));
                        final three.BoundingBox box = three.BoundingBox();
                        box.setFromObject(obj);     
                        BoundingBoxHelper h = BoundingBoxHelper(box)..visible = false;
                        obj.name = 'Text';
                        obj.scale = three.Vector3(0.01,0.01,0.01);
                        threeJs.scene.add(obj.add(h));
                        setState(() {});
                      }
                    ),
                  ]
                ),
              ]
            ),
        ),
        body: Row(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width*.8,
                  child: threeJs.build(),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: (){
                          setState(() {
                            control.setMode( 'translate' );
                          });
                        },
                        child:Container(
                          width: 35,
                          height: 35,
                          color: threeJs.mounted && control.enabled && control.mode == 'translate'? CSS.darkTheme.secondaryHeaderColor.withAlpha(200):CSS.darkTheme.cardColor.withAlpha(200),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.control_camera,
                            size: 30,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: (){
                          setState(() {
                            control.setMode( 'rotate' );
                          });
                        },
                        child:Container(
                          width: 35,
                          height: 35,
                          margin: const EdgeInsets.only(top: 2),
                          color: threeJs.mounted && control.enabled && control.mode == 'rotate'? CSS.darkTheme.secondaryHeaderColor.withAlpha(200):CSS.darkTheme.cardColor.withAlpha(200),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.cached,
                            size: 30,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: (){
                          setState(() {
                            control.setMode( 'scale' );
                          });
                        },
                        child: Container(
                          width: 35,
                          height: 35,
                          margin: const EdgeInsets.only(top: 2),
                          color: threeJs.mounted && control.enabled && control.mode == 'scale'? CSS.darkTheme.secondaryHeaderColor.withAlpha(200):CSS.darkTheme.cardColor.withAlpha(200),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.aspect_ratio,
                            size: 30,
                          ),
                        )
                      )
                    ],
                  )
                ),
                Positioned(
                  right: 10,
                  top: 120,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: (){
                          final position = threeJs.camera.position.clone();

                          threeJs.camera = threeJs.camera is three.PerspectiveCamera ?cameraOrtho:cameraPersp;
                          threeJs.camera.position.setFrom( position );

                          orbit.object = threeJs.camera;
                          control.camera = threeJs.camera;

                          threeJs.camera.lookAt(orbit.target);
                          threeJs.onWindowResize(context);
                        },
                        child:Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25/2),
                            color: CSS.darkTheme.cardColor.withAlpha(200),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.grid_on_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ]
                  )
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: (){
                          materialWireframe(threeJs.scene.children.sublist(5), true);
                          setState(() {
                            shading = ShadingType.wireframe;
                          });
                        },
                        child:Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(5),
                              bottomLeft: Radius.circular(5)
                            ),
                            color: shading != ShadingType.wireframe?CSS.darkTheme.cardColor:CSS.darkTheme.secondaryHeaderColor,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sports_basketball_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: (){
                          materialWireframe(threeJs.scene.children.sublist(5), false);
                          setState(() {
                            shading = ShadingType.solid;
                          });
                        },
                        child:Container(
                          margin: const EdgeInsets.fromLTRB(2,0,2,0),
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: shading == ShadingType.solid?CSS.darkTheme.secondaryHeaderColor:CSS.darkTheme.cardColor,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.brightness_1,
                            size: 20,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: (){

                        },
                        child:Container(
                          margin: const EdgeInsets.fromLTRB(0,0,2,0),
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: CSS.darkTheme.cardColor,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.blur_on_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: (){

                        },
                        child:Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(5),
                              bottomRight: Radius.circular(5)
                            ),
                            color: CSS.darkTheme.cardColor,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.radio_button_off,
                            size: 20,
                          ),
                        ),
                      ),
                    ]
                  )
                ),
              ]
            ),
            Container(
              width: MediaQuery.of(context).size.width*.2,
              color: CSS.darkTheme.cardColor,
              child: Column(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height/3,
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: CSS.darkTheme.canvasColor,
                      borderRadius: BorderRadius.circular(5)
                    ),
                    child: threeJs.mounted?sceneCollection():Container(),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height - MediaQuery.of(context).size.height/3 - 40,
                    margin: const EdgeInsets.fromLTRB(5,0,5,5),
                    decoration: BoxDecoration(
                      color: CSS.darkTheme.canvasColor,
                      borderRadius: BorderRadius.circular(5)
                    ),
                    child: threeJs.mounted && intersected != null?intersectedData():Container(),
                  )
                ],
              ),
            ),
          ],
        )
      ),
    );
  }
}


class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({this.decimalRange = 6});

  final int decimalRange;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, // unused.
    TextEditingValue newValue,
  ) {
    TextSelection newSelection = newValue.selection;
    String truncated = newValue.text;

    if (decimalRange != null) {
      String value = newValue.text;

      if (value.contains(".") &&
          value.substring(value.indexOf(".") + 1).length > decimalRange) {
        truncated = oldValue.text;
        newSelection = oldValue.selection;
      } else if (value == ".") {
        truncated = "0.";

        newSelection = newValue.selection.copyWith(
          baseOffset: math.min(truncated.length, truncated.length + 1),
          extentOffset: math.min(truncated.length, truncated.length + 1),
        );
      }

      return TextEditingValue(
        text: truncated,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }
    return newValue;
  }
}
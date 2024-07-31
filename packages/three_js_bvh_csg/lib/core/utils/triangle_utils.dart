import 'package:vector_math/vector_math_64.dart';

const double EPSILON = 1e-14;
var _AB = Vector3.zero();
var _AC = Vector3.zero();
var _CB = Vector3.zero();

bool isTriDegenerate(tri, [double eps = EPSILON]) {
  _AB
    ..setFrom(tri.point1)
    ..sub(tri.point0);
  _AC
    ..setFrom(tri.point2)
    ..sub(tri.point0);
  _CB
    ..setFrom(tri.point2)
    ..sub(tri.point1);

  double angle1 = _AB.angleTo(_AC); // AB v AC
  double angle2 = _AB.angleTo(_CB); // AB v BC
  double angle3 = 3.141592653589793 - angle1 - angle2; // 180deg - angle1 - angle2

  return angle1.abs() < eps ||
      angle2.abs() < eps ||
      angle3.abs() < eps ||
      tri.a.distanceToSquared(tri.b) < eps ||
      tri.a.distanceToSquared(tri.c) < eps ||
      tri.b.distanceToSquared(tri.c) < eps;
}

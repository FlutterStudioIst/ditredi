import 'package:ditredi/src/controller/ditredi_controller.dart';
import 'package:ditredi/src/extensions/double_extensions.dart';
import 'package:ditredi/src/model/ditredi_config.dart';
import 'package:ditredi/src/model/model_3d.dart';
import 'package:ditredi/src/painter/canvas_model_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math' as math;

export 'package:ditredi/src/extensions/double_extensions.dart';
export 'package:ditredi/src/extensions/iterable_extensions.dart';
export 'package:ditredi/src/extensions/vector_extensions.dart';
export 'package:ditredi/src/model/axis.dart';
export 'package:ditredi/src/model/model_3d.dart';
export 'package:ditredi/src/model/ditredi_config.dart';
export 'package:ditredi/src/model/modifier_3d.dart';
export 'package:ditredi/src/model/vertices/line_3.dart';
export 'package:ditredi/src/model/vertices/poly_line3.dart';
export 'package:ditredi/src/parser/csv_parser.dart';
export 'package:ditredi/src/parser/obj_parser.dart';
export 'package:ditredi/src/controller/ditredi_controller.dart';
export 'package:ditredi/src/painter/model/face_3d_painter.dart';
export 'package:ditredi/src/painter/model/group_3d_painter.dart';
export 'package:ditredi/src/painter/model/line_3d_painter.dart';
export 'package:ditredi/src/painter/model/model_3d_painter.dart';
export 'package:ditredi/src/painter/model/point_3d_painter.dart';

/// A widget that displays a 3D objects.
class DiTreDi extends StatelessWidget {
  /// List of [Model3D] to display.
  final List<Model3D> figures;

  /// Bounds of the 3D space.
  final Aabb3? bounds;

  /// The [DitrediConfig] to use.
  final DiTreDiConfig config;

  /// The controller to controll the camera.
  final DiTreDiController controller;

  /// Creates a [DiTreDi] widget.
  DiTreDi({
    Key? key,
    required this.figures,
    DiTreDiController? controller,
    this.config = const DiTreDiConfig(),
    this.bounds,
  })  : controller = controller ?? DiTreDiController(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        size: Size.infinite,
        painter: CanvasModelPainter(
          figures,
          bounds,
          controller,
          config,
        ),
      ),
    );
  }
}

/// A widget that controls the [DiTreDi] camera with gestures.
class DiTreDiDraggable extends StatefulWidget {
  /// The [DiTreDiController] to control.
  /// Should be the same as the one used in the [DiTreDi] widget.
  final DiTreDiController controller;

  /// The [DiTreDi] widget or its container.
  final Widget child;

  /// If true, the camera will be rotated with the finger.
  final bool rotationEnabled;

  /// If true, the zoom will be changed with the mouse scroll.
  final bool scaleEnabled;

  /// Creates a [DiTreDiDraggable] widget.
  const DiTreDiDraggable({
    Key? key,
    required this.controller,
    required this.child,
    this.rotationEnabled = true,
    this.scaleEnabled = true,
  }) : super(key: key);

  @override
  State<DiTreDiDraggable> createState() => _DiTreDiDraggableState();
}

class _DiTreDiDraggableState extends State<DiTreDiDraggable> {
  var _lastX = 0.0;
  var _lastY = 0.0;
  var _scaleBase = 0.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (widget.scaleEnabled && pointerSignal is PointerScrollEvent) {
          final scaledDy =
              pointerSignal.scrollDelta.dy / widget.controller.viewScale;
          widget.controller.update(
            userScale: widget.controller.userScale - scaledDy,
          );
        }
      },
      child: GestureDetector(
        onScaleStart: (data) {
          _scaleBase = widget.controller.userScale;
          _lastX = data.localFocalPoint.dx;
          _lastY = data.localFocalPoint.dy;
        },
        onScaleUpdate: (data) {
          final controller = widget.controller;

          final dx = data.localFocalPoint.dx - _lastX;
          final dy = data.localFocalPoint.dy - _lastY;

          _lastX = data.localFocalPoint.dx;
          _lastY = data.localFocalPoint.dy;

          controller.update(
            userScale: _scaleBase * data.scale,
            rotationX: widget.rotationEnabled
                ? (controller.rotationX - dy / 2).clamp(-90, -20)
                : null,
            rotationY: widget.rotationEnabled
                ? ((controller.rotationY - dx / 2 + 360) % 360).clamp(0, 360)
                : null,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A widget that controls the [DiTreDi] camera with gestures.
class DiTreDiAlternativeDraggable extends StatefulWidget {
  /// The [DiTreDiController] to control.
  /// Should be the same as the one used in the [DiTreDi] widget.
  final DiTreDiController controller;

  /// The [DiTreDi] widget or its container.
  final Widget child;

  /// If true, the camera will be rotated with the finger.
  final bool rotationEnabled;

  /// If true, the zoom will be changed with the mouse scroll.
  final bool scaleEnabled;

  /// The sensitivity of the rotation.
  final double rotationSensitivity;

  /// Creates a [DiTreDiAlternativeDraggable] widget.
  const DiTreDiAlternativeDraggable({
    Key? key,
    required this.controller,
    required this.child,
    this.rotationEnabled = true,
    this.scaleEnabled = true,
    this.rotationSensitivity = 0.01,
  }) : super(key: key);

  @override
  State<DiTreDiAlternativeDraggable> createState() =>
      _DiTreDiAlternativeDraggableState();
}

class _DiTreDiAlternativeDraggableState
    extends State<DiTreDiAlternativeDraggable> {
  var _lastX = 0.0;
  var _lastY = 0.0;
  var _scaleBase = 0.0;
  final _rotationMatrix = Matrix3.identity();

  @override
  void initState() {
    super.initState();

    double initialRadZ = widget.controller.rotationZ.toRadians();
    double initialRadY = widget.controller.rotationY.toRadians();
    double initialRadX = widget.controller.rotationX.toRadians();

    _rotationMatrix.multiply(Matrix3.rotationZ(initialRadZ));
    _rotationMatrix.multiply(Matrix3.rotationY(initialRadY));
    _rotationMatrix.multiply(Matrix3.rotationX(initialRadX));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (widget.scaleEnabled && pointerSignal is PointerScrollEvent) {
          final scaledDy =
              pointerSignal.scrollDelta.dy / widget.controller.viewScale;
          widget.controller.update(
            userScale: widget.controller.userScale - scaledDy,
          );
        }
      },
      child: GestureDetector(
        onScaleStart: (data) {
          _scaleBase = widget.controller.userScale;
          _lastX = data.localFocalPoint.dx;
          _lastY = data.localFocalPoint.dy;
        },
        onScaleUpdate: (data) {
          final controller = widget.controller;

          final dx = data.localFocalPoint.dx - _lastX;
          final dy = data.localFocalPoint.dy - _lastY;

          _lastX = data.localFocalPoint.dx;
          _lastY = data.localFocalPoint.dy;

          var (degX, degY, degZ) = computeNewControllerRotations(dx, dy);

          controller.update(
            userScale: _scaleBase * data.scale,
            rotationX: degX,
            rotationY: degY,
            rotationZ: degZ,
          );
        },
        child: widget.child,
      ),
    );
  }

  (double?, double?, double?) computeNewControllerRotations(
      double dx, double dy) {
    if (!widget.rotationEnabled) {
      return (null, null, null);
    }

    final sensitivity = widget.rotationSensitivity;
    _rotationMatrix.multiply(Matrix3.rotationX(-dy * sensitivity));
    _rotationMatrix.multiply(Matrix3.rotationY(-dx * sensitivity));

    double r11 = _rotationMatrix.entry(0, 0);
    double r21 = _rotationMatrix.entry(1, 0);
    double r31 = _rotationMatrix.entry(2, 0);
    double r32 = _rotationMatrix.entry(2, 1);
    double r33 = _rotationMatrix.entry(2, 2);

    double radX = math.atan2(r32, r33);
    double radY = math.asin(r31);
    double radZ = math.atan2(r21, r11);

    double degX = degrees(radX);
    double degY = (degrees(radY) + 360) % 360;
    double degZ = degrees(radZ);

    return (degX, degY, degZ);
  }
}

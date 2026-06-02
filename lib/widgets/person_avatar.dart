import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/person.dart';

class PersonAvatar extends StatelessWidget {
  final MoodType mood;
  final double size;
  final bool isMyProfile;
  final GenderType gender;
  final int avatarVariant;
  final String? customAsset;

  const PersonAvatar({
    super.key,
    required this.mood,
    required this.gender,
    required this.avatarVariant,
    this.size = 72,
    this.isMyProfile = false,
    this.customAsset,
  });

  Color _backgroundColor(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return const Color(0xFFFFC857);
      case MoodType.calm:
        return const Color(0xFF6FCF97);
      case MoodType.sad:
        return const Color(0xFF5B8DEF);
      case MoodType.irritated:
        return const Color(0xFFFF6B6B);
      case MoodType.tired:
        return const Color(0xFF9B7EDE);
      case MoodType.needsCare:
        return const Color(0xFFFF8CC8);
    }
  }

  String _genderKey(GenderType gender) {
    switch (gender) {
      case GenderType.male:
        return 'male';
      case GenderType.female:
        return 'female';
    }
  }

  String _moodKey(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'happy';
      case MoodType.calm:
        return 'calm';
      case MoodType.sad:
        return 'sad';
      case MoodType.irritated:
        return 'irritated';
      case MoodType.tired:
        return 'tired';
      case MoodType.needsCare:
        return 'needs_care';
    }
  }

  String _primaryAssetPath() {
    return 'assets/avatars/${_genderKey(gender)}_${avatarVariant}_${_moodKey(mood)}.png';
  }

  String _secondaryAssetPath() {
    return 'assets/avatars/${_genderKey(gender)}_${avatarVariant}_${_moodKey(mood)}.webp';
  }

  double _bodyTilt(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return -0.08;
      case MoodType.calm:
        return 0.0;
      case MoodType.sad:
        return 0.04;
      case MoodType.irritated:
        return -0.04;
      case MoodType.tired:
        return 0.06;
      case MoodType.needsCare:
        return 0.02;
    }
  }

  double _headTilt(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return -0.10;
      case MoodType.calm:
        return 0.0;
      case MoodType.sad:
        return 0.06;
      case MoodType.irritated:
        return -0.06;
      case MoodType.tired:
        return 0.10;
      case MoodType.needsCare:
        return -0.03;
    }
  }

Widget _buildAvatarFigure() {
  if (customAsset != null) {
    return Image.asset(
      customAsset!,
      width: size * 0.9,
      height: size * 0.9,
      fit: BoxFit.contain,
    );
  }

  return Image.asset(
    _primaryAssetPath(),
    width: size * 0.88,
    height: size * 0.88,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) {
      return Image.asset(
        _secondaryAssetPath(),
        width: size * 0.88,
        height: size * 0.88,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return _AvatarFigure(
            mood: mood,
            size: size,
            bodyColor: Colors.white,
            bodyTilt: _bodyTilt(mood),
            headTilt: _headTilt(mood),
            gender: gender,
            avatarVariant: avatarVariant,
          );
        },
      );
    },
  );
}

  @override
Widget build(BuildContext context) {
  final bg = _backgroundColor(mood);

  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: size * 0.18,
            sigmaY: size * 0.18,
          ),
          child: Container(
            width: size * 1.04,
            height: size * 1.04,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  bg.withValues(alpha: 0.88),
                  bg.withValues(alpha: 0.34),
                  bg.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.14, 0.42, 0.72, 1.0],
              ),
            ),
          ),
        ),
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: size * 0.08,
            sigmaY: size * 0.08,
          ),
          child: Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg.withValues(alpha: 0.12),
            ),
          ),
        ),
        _buildAvatarFigure(),
      ],
    ),
  );
}
}

class _AvatarFigure extends StatelessWidget {
  final MoodType mood;
  final double size;
  final Color bodyColor;
  final double bodyTilt;
  final double headTilt;
  final GenderType gender;
  final int avatarVariant;

  const _AvatarFigure({
    required this.mood,
    required this.size,
    required this.bodyColor,
    required this.bodyTilt,
    required this.headTilt,
    required this.gender,
    required this.avatarVariant,
  });

  Color get _featureColor => const Color(0xFF2A2A33);

  @override
  Widget build(BuildContext context) {
    final headSize = size * 0.20;
    final torsoWidth = _torsoWidth();
    final torsoHeight = _torsoHeight();
    final limbThickness = math.max(2.0, size * 0.032);

    return SizedBox(
      width: size * 0.64,
      height: size * 0.74,
      child: Transform.rotate(
        angle: bodyTilt,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.07,
              child: Transform.rotate(
                angle: headTilt,
                child: SizedBox(
                  width: headSize * 1.12,
                  height: headSize * 1.16,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(headSize * 1.12, headSize * 1.16),
                        painter: _HairPainter(
                          gender: gender,
                          avatarVariant: avatarVariant,
                          color: bodyColor,
                        ),
                      ),
                      Positioned(
                        top: headSize * 0.16,
                        child: Container(
                          width: headSize,
                          height: headSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bodyColor,
                          ),
                          child: CustomPaint(
                            painter: _FacePainter(
                              mood: mood,
                              variant: avatarVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: size * 0.25,
              child: Container(
                width: torsoWidth,
                height: torsoHeight,
                decoration: BoxDecoration(
                  color: bodyColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(size * 0.10),
                    bottom: Radius.circular(_bottomRadius()),
                  ),
                ),
              ),
            ),
            if (_needsSkirt())
              Positioned(
                top: size * 0.39,
                child: CustomPaint(
                  size: Size(size * 0.20, size * 0.12),
                  painter: _SkirtPainter(color: bodyColor),
                ),
              ),
            Positioned(
              top: size * 0.28,
              left: size * 0.035,
              child: Transform.rotate(
                angle: _leftArmAngle(mood),
                alignment: Alignment.topCenter,
                child: Container(
                  width: limbThickness,
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    color: bodyColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Positioned(
              top: size * 0.28,
              right: size * 0.035,
              child: Transform.rotate(
                angle: _rightArmAngle(mood),
                alignment: Alignment.topCenter,
                child: Container(
                  width: limbThickness,
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    color: bodyColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Positioned(
              top: size * 0.45,
              left: size * 0.18,
              child: Transform.rotate(
                angle: _leftLegAngle(mood),
                alignment: Alignment.topCenter,
                child: Container(
                  width: limbThickness,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    color: bodyColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Positioned(
              top: size * 0.45,
              right: size * 0.18,
              child: Transform.rotate(
                angle: _rightLegAngle(mood),
                alignment: Alignment.topCenter,
                child: Container(
                  width: limbThickness,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    color: bodyColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            if (_hasAccessory())
              Positioned(
                top: size * 0.21,
                child: Icon(
                  _accessoryIcon(),
                  size: size * 0.08,
                  color: _featureColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _torsoWidth() {
    if (gender == GenderType.female) {
      return avatarVariant == 1 ? size * 0.18 : size * 0.20;
    }
    return avatarVariant == 2 ? size * 0.22 : size * 0.20;
  }

  double _torsoHeight() {
    if (gender == GenderType.female) {
      return avatarVariant == 2 ? size * 0.21 : size * 0.23;
    }
    return avatarVariant == 1 ? size * 0.24 : size * 0.23;
  }

  double _bottomRadius() {
    if (_needsSkirt()) return size * 0.03;
    return size * 0.08;
  }

  bool _needsSkirt() {
    return gender == GenderType.female && avatarVariant == 1;
  }

  bool _hasAccessory() {
    return avatarVariant == 2;
  }

  IconData _accessoryIcon() {
    return gender == GenderType.female ? Icons.star : Icons.circle;
  }

  double _leftArmAngle(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return -0.9;
      case MoodType.calm:
        return -0.25;
      case MoodType.sad:
        return 0.20;
      case MoodType.irritated:
        return -0.45;
      case MoodType.tired:
        return 0.35;
      case MoodType.needsCare:
        return -0.10;
    }
  }

  double _rightArmAngle(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 0.9;
      case MoodType.calm:
        return 0.25;
      case MoodType.sad:
        return -0.20;
      case MoodType.irritated:
        return 0.45;
      case MoodType.tired:
        return -0.35;
      case MoodType.needsCare:
        return 0.10;
    }
  }

  double _leftLegAngle(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return -0.18;
      case MoodType.calm:
        return -0.05;
      case MoodType.sad:
        return -0.02;
      case MoodType.irritated:
        return -0.12;
      case MoodType.tired:
        return 0.08;
      case MoodType.needsCare:
        return -0.04;
    }
  }

  double _rightLegAngle(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 0.18;
      case MoodType.calm:
        return 0.05;
      case MoodType.sad:
        return 0.02;
      case MoodType.irritated:
        return 0.12;
      case MoodType.tired:
        return -0.08;
      case MoodType.needsCare:
        return 0.04;
    }
  }
}

class _HairPainter extends CustomPainter {
  final GenderType gender;
  final int avatarVariant;
  final Color color;

  const _HairPainter({
    required this.gender,
    required this.avatarVariant,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    if (gender == GenderType.male) {
      if (avatarVariant == 0) {
        path.moveTo(size.width * 0.25, size.height * 0.38);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.02,
          size.width * 0.78,
          size.height * 0.38,
        );
        path.lineTo(size.width * 0.75, size.height * 0.48);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.22,
          size.width * 0.28,
          size.height * 0.48,
        );
      } else if (avatarVariant == 1) {
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.23,
              size.height * 0.16,
              size.width * 0.56,
              size.height * 0.34,
            ),
            Radius.circular(size.width * 0.12),
          ),
        );
      } else {
        path.moveTo(size.width * 0.22, size.height * 0.34);
        path.quadraticBezierTo(
          size.width * 0.52,
          size.height * 0.08,
          size.width * 0.80,
          size.height * 0.34,
        );
        path.lineTo(size.width * 0.73, size.height * 0.54);
        path.lineTo(size.width * 0.30, size.height * 0.54);
      }
    } else {
      if (avatarVariant == 0) {
        path.moveTo(size.width * 0.22, size.height * 0.30);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.00,
          size.width * 0.80,
          size.height * 0.30,
        );
        path.lineTo(size.width * 0.82, size.height * 0.76);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.96,
          size.width * 0.18,
          size.height * 0.76,
        );
      } else if (avatarVariant == 1) {
        path.moveTo(size.width * 0.20, size.height * 0.28);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.02,
          size.width * 0.82,
          size.height * 0.28,
        );
        path.lineTo(size.width * 0.68, size.height * 0.82);
        path.lineTo(size.width * 0.34, size.height * 0.82);
      } else {
        path.addOval(
          Rect.fromLTWH(
            size.width * 0.18,
            size.height * 0.10,
            size.width * 0.64,
            size.height * 0.54,
          ),
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HairPainter oldDelegate) {
    return oldDelegate.gender != gender ||
        oldDelegate.avatarVariant != avatarVariant ||
        oldDelegate.color != color;
  }
}

class _SkirtPainter extends CustomPainter {
  final Color color;

  const _SkirtPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.10)
      ..lineTo(size.width * 0.80, size.height * 0.10)
      ..lineTo(size.width * 0.92, size.height * 0.95)
      ..lineTo(size.width * 0.08, size.height * 0.95)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SkirtPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FacePainter extends CustomPainter {
  final MoodType mood;
  final int variant;

  const _FacePainter({
    required this.mood,
    required this.variant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.065)
      ..strokeCap = StrokeCap.round;

    final eyePaint = Paint()
      ..color = const Color(0xFF2A2A33)
      ..style = PaintingStyle.fill;

    final eyeYOffset = variant == 1 ? 0.44 : 0.42;
    final leftEye = Offset(size.width * 0.36, size.height * eyeYOffset);
    final rightEye = Offset(size.width * 0.64, size.height * eyeYOffset);

    switch (mood) {
      case MoodType.happy:
        canvas.drawCircle(leftEye, size.width * 0.045, eyePaint);
        canvas.drawCircle(rightEye, size.width * 0.045, eyePaint);
        final mouthRect = Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.60),
          width: size.width * 0.30,
          height: size.height * 0.18,
        );
        canvas.drawArc(mouthRect, 0.15, math.pi - 0.30, false, paint);
        break;

      case MoodType.calm:
        canvas.drawCircle(leftEye, size.width * 0.04, eyePaint);
        canvas.drawCircle(rightEye, size.width * 0.04, eyePaint);
        canvas.drawLine(
          Offset(size.width * 0.40, size.height * 0.62),
          Offset(size.width * 0.60, size.height * 0.62),
          paint,
        );
        break;

      case MoodType.sad:
        canvas.drawCircle(leftEye, size.width * 0.04, eyePaint);
        canvas.drawCircle(rightEye, size.width * 0.04, eyePaint);
        final mouthRect = Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.72),
          width: size.width * 0.28,
          height: size.height * 0.16,
        );
        canvas.drawArc(mouthRect, math.pi + 0.25, math.pi - 0.50, false, paint);
        break;

      case MoodType.irritated:
        canvas.drawLine(
          Offset(size.width * 0.28, size.height * 0.36),
          Offset(size.width * 0.40, size.height * 0.40),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.72, size.height * 0.36),
          Offset(size.width * 0.60, size.height * 0.40),
          paint,
        );
        canvas.drawCircle(leftEye, size.width * 0.038, eyePaint);
        canvas.drawCircle(rightEye, size.width * 0.038, eyePaint);
        canvas.drawLine(
          Offset(size.width * 0.38, size.height * 0.66),
          Offset(size.width * 0.62, size.height * 0.66),
          paint,
        );
        break;

      case MoodType.tired:
        canvas.drawLine(
          Offset(size.width * 0.30, size.height * 0.42),
          Offset(size.width * 0.42, size.height * 0.42),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.58, size.height * 0.42),
          Offset(size.width * 0.70, size.height * 0.42),
          paint,
        );
        final mouthRect = Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.63),
          width: size.width * 0.16,
          height: size.height * 0.12,
        );
        canvas.drawArc(mouthRect, 0, math.pi, false, paint);
        break;

      case MoodType.needsCare:
        canvas.drawCircle(leftEye, size.width * 0.05, eyePaint);
        canvas.drawCircle(rightEye, size.width * 0.05, eyePaint);
        final mouthRect = Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.66),
          width: size.width * 0.18,
          height: size.height * 0.14,
        );
        canvas.drawArc(mouthRect, math.pi + 0.10, math.pi - 0.20, false, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.variant != variant;
  }
}
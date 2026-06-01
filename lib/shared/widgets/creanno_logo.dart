import 'package:flutter/material.dart';

// ─── Square icon logo (CREANNO_Icon.png 1024×1024) ───────────────────────────
/// Shows the CREANNO square CE icon at [size]×[size].
/// Use on dark/gradient backgrounds with [light] = true (adds white border).
class CreannoLogo extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const CreannoLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/CREANNO_Icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ─── Light variant (for use on gradient/dark backgrounds) ────────────────────
class CreannoLogoLight extends StatelessWidget {
  final double size;
  final bool showTagline;

  const CreannoLogoLight({
    super.key,
    this.size = 48,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: size * 0.3,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/CREANNO_Icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.18),
          Text(
            'Create · Innovate',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: size * 0.22,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Wide logo banner (CREANNO_Logo.png 512×200) ─────────────────────────────
/// Shows the full-width CREANNO logo (CE mark + Create·Innovate tagline).
/// [width] controls display width; height scales proportionally (ratio 2.56:1).
class CreannoLogoWide extends StatelessWidget {
  final double width;

  const CreannoLogoWide({super.key, this.width = 200});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/CREANNO_Logo.png',
      width: width,
      height: width / 2.56, // preserves 512:200 aspect ratio
      fit: BoxFit.contain,
    );
  }
}

(* Process values are REAL; each widget turns them into a per-mille fill once per frame and draws in integers. *)

(* Position of Value between MinValue and MaxValue, in per-mille (0..1000). *)
FUNCTION HMI_PerMille : DINT
  VAR_INPUT Value, MinValue, MaxValue : REAL; END_VAR
  VAR span : REAL; END_VAR
  span := MaxValue - MinValue;
  IF ABS(span) < 0.0001 OR Value <> Value THEN
    HMI_PerMille := 0;
  ELSE
    HMI_PerMille := REAL_TO_DINT(LIMIT(0.0, (Value - MinValue) * 1000.0 / span, 1000.0));
  END_IF;
END_FUNCTION

(* Filled rectangle, optionally rounded and outlined. *)
{attribute 'hmi_palette' := 'Shapes'}
{attribute 'hmi_default' := 'AutoSize := TRUE'}
FUNCTION_BLOCK HmiRect EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_color'}
    Fill : UDINT := COLOR.Surface;
    {attribute 'hmi_color'}
    Border : UDINT := COLOR.Border;
    BorderWidth : DINT := 1;
    Radius : DINT := 8;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 160;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 96;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    HMI_FillRect(Left, Top, Width, Height, Sc(Radius), Fill);
    IF BorderWidth > 0 THEN
      HMI_StrokeRect(Left, Top, Width, Height, Sc(Radius), Sc(BorderWidth), Border);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Filled ellipse inscribed in the element's rectangle, optionally outlined; a circle when the rectangle is square. *)
{attribute 'hmi_palette' := 'Shapes'}
{attribute 'hmi_default' := 'AutoSize := TRUE'}
FUNCTION_BLOCK HmiEllipse EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_color'}
    Fill : UDINT := COLOR.Surface;
    {attribute 'hmi_color'}
    Border : UDINT := COLOR.Border;
    BorderWidth : DINT := 1;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 96;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 96;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    HMI_FillEllipse(CenterX(), CenterY(), Width / 2, Height / 2, Fill);
    IF BorderWidth > 0 THEN
      HMI_StrokeEllipse(CenterX(), CenterY(), Width / 2, Height / 2, Sc(BorderWidth), Border);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Regular polygon of 3 to 32 Sides inscribed in the element's rectangle, its first vertex at Rotation degrees
   (clockwise from 3 o'clock). InnerPct below 100 makes it a star, its inner vertices at that percent of the radius. *)
{attribute 'hmi_palette' := 'Shapes'}
{attribute 'hmi_default' := 'AutoSize := TRUE'}
FUNCTION_BLOCK HmiPolygon EXTENDS HmiElement
  VAR_INPUT
    Sides : DINT := 3;
    Rotation : DINT := -90;
    InnerPct : DINT := 100;
    {attribute 'hmi_color'}
    Fill : UDINT := COLOR.Surface;
    {attribute 'hmi_color'}
    Border : UDINT := COLOR.Border;
    BorderWidth : DINT := 1;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 96;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 96;
  END_METHOD
  (* Starts a polygon in color C and adds the vertices. *)
  METHOD INTERNAL Trace : BOOL
    VAR_INPUT C : UDINT; END_VAR
    VAR n, k, i, a, rx, ry, pct : DINT; END_VAR
    n := LIMIT(3, Sides, 32);
    pct := LIMIT(0, InnerPct, 100);
    k := n;
    IF pct < 100 THEN
      k := 2 * n;
    END_IF;
    rx := Width / 2;
    ry := Height / 2;
    HMI_PolyBegin(C);
    FOR i := 0 TO k - 1 DO
      a := Rotation + i * 360 / k;
      IF k > n AND i MOD 2 = 1 THEN
        HMI_PolyPoint(CenterX() + HMI_Cos(a, rx * pct / 100), CenterY() + HMI_Sin(a, ry * pct / 100));
      ELSE
        HMI_PolyPoint(CenterX() + HMI_Cos(a, rx), CenterY() + HMI_Sin(a, ry));
      END_IF;
    END_FOR;
    Trace := TRUE;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    Trace(Fill);
    HMI_PolyFill();
    IF BorderWidth > 0 THEN
      Trace(Border);
      HMI_PolyStroke(Sc(BorderWidth), TRUE);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Straight line through the centre of the element's rectangle at Angle degrees: 0 across, 90 down, 45 diagonal. *)
{attribute 'hmi_palette' := 'Shapes'}
{attribute 'hmi_default' := 'AutoSize := TRUE'}
FUNCTION_BLOCK HmiLine EXTENDS HmiElement
  VAR_INPUT
    Angle : DINT;
    Thickness : DINT := 2;
    {attribute 'hmi_color'}
    LineColor : UDINT := COLOR.Text;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 160;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 16;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR dx, dy, t : DINT; END_VAR
    t := Sc(Thickness);
    dx := HMI_Cos(Angle, MAX(Width / 2 - t / 2, 0));
    dy := HMI_Sin(Angle, MAX(Height / 2 - t / 2, 0));
    HMI_Line(CenterX() - dx, CenterY() - dy, CenterX() + dx, CenterY() + dy, t, LineColor);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiLabel EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Text : STRING(64) := 'Label';
    Size : DINT := 16;
    Font : HMI_FONT := HMI_FONT#Regular;
    {attribute 'hmi_color'}
    TextColor : UDINT := COLOR.Text;
    Align : HMI_ALIGN := HMI_ALIGN#Left;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := HMI_TextWidth(Text, Size, Font) + 8;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := Size * 3 / 2 + 8;
  END_METHOD
  (* With a preferred width, the natural width without the text, so a changing text keeps the scale; else the
     natural width the box follows. *)
  METHOD PROTECTED OVERRIDE ScaleWidth : DINT
    IF PrefWidth > 0 THEN
      ScaleWidth := 8;
    ELSE
      ScaleWidth := NaturalWidth();
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    HMI_TextBox(Left, Top, Width, Height, Text, FitSize(Text, Sc(Size), Font, Width), Font, Align, HMI_VALIGN#Middle,
      TextColor);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* A number with its caption and unit. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiValue EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    Decimals : INT := 1;
    Caption : STRING(64) := 'Value';
    Unit : STRING(16);
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Text;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 144;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 64;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    HMI_FillRect(Left, Top, Width, Height, Sc(8), COLOR.Surface);
    HMI_StrokeRect(Left, Top, Width, Height, Sc(8), Sc(1), COLOR.Border);
    HMI_Text(Left + Sc(10), Top + Sc(6), Caption, Sc(12), HMI_FONT#Regular, HMI_ALIGN#Left, COLOR.TextMuted);
    HMI_TextBox(Left + Sc(10), Top + Sc(22), Width - Sc(20), Height - Sc(28), HMI_FormatValue(Value, Decimals, Unit),
      Sc(22), HMI_FONT#Bold,
      HMI_ALIGN#Right, HMI_VALIGN#Middle, AccentColor);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Indicator light with a caption. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiLamp EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : BOOL;
    Caption : STRING(64) := 'Lamp';
    (* Flashes twice a second while on. *)
    Blink : BOOL;
    {attribute 'hmi_color'}
    OnColor : UDINT := COLOR.Success;
    {attribute 'hmi_color'}
    OffColor : UDINT := COLOR.Border;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := HMI_TextWidth(Caption, 16, HMI_FONT#Regular) + 52;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 36;
  END_METHOD
  (* With a preferred width, the natural width without the caption, so a changing caption keeps the scale; else the
     natural width the box follows. *)
  METHOD PROTECTED OVERRIDE ScaleWidth : DINT
    IF PrefWidth > 0 THEN
      ScaleWidth := 52;
    ELSE
      ScaleWidth := NaturalWidth();
    END_IF;
  END_METHOD
  (* The light is the natural 36 lu at the lamp's scale, centred vertically. *)
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR d, r, cx, cy : DINT; lit : BOOL; END_VAR
    d := MIN(Height, Sc(36));
    r := MAX(d / 2 - Sc(4), Sc(2));
    cx := Left + d / 2;
    cy := Top + Height / 2;
    lit := Value AND NOT (Blink AND (HMI_TimeMs() / 250) MOD 2 = 1);
    IF lit THEN
      HMI_FillCircle(cx, cy, r + Sc(4), HMI_Alpha(OnColor, 13));
    END_IF;
    HMI_FillCircle(cx, cy, r, SEL(lit, OffColor, OnColor));
    HMI_TextBox(Left + d + Sc(8), Top, Width - d - Sc(8), Height, Caption,
      FitSize(Caption, Sc(16), HMI_FONT#Regular, Width - d - Sc(8)), HMI_FONT#Regular, HMI_ALIGN#Left, HMI_VALIGN#Middle,
      COLOR.Text);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* 270-degree arc gauge; the arc eases toward the value. *)
{attribute 'hmi_palette' := 'Display'}
{attribute 'hmi_default' := 'AutoSize := TRUE'}
FUNCTION_BLOCK HmiGauge EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    MinValue : REAL := 0.0;
    MaxValue : REAL := 100.0;
    Decimals : INT := 1;
    Unit : STRING(16) := '%';
    Caption : STRING(64) := 'Gauge';
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Accent;
  END_VAR
  VAR
    shownPm : DINT;
    started : BOOL;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 144;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 144;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR cx, cy, r, pm, th, d : DINT; END_VAR
    pm := HMI_PerMille(Value, MinValue, MaxValue);
    IF NOT started THEN
      shownPm := pm;
      started := TRUE;
    END_IF;
    d := (pm - shownPm) / 4;
    IF d = 0 THEN
      shownPm := pm;
    ELSE
      shownPm := shownPm + d;
    END_IF;
    cx := Left + Width / 2;
    cy := Top + Height / 2 + Sc(6);
    r := MIN(Width, Height) / 2 - Sc(14);
    (* Too small for a dial: the caption alone. *)
    IF r < Sc(8) THEN
      HMI_Text(cx, Top + Height - Sc(18), Caption, Sc(14), HMI_FONT#Regular, HMI_ALIGN#Center, COLOR.TextMuted);
      Draw := TRUE;
      RETURN;
    END_IF;
    th := MAX(Sc(6), r / 6);
    HMI_Arc(cx, cy, r, th, 135, 405, COLOR.Fill);
    IF shownPm > 0 THEN
      HMI_Arc(cx, cy, r, th, 135, 135 + 270 * shownPm / 1000, AccentColor);
    END_IF;
    HMI_Text(cx, cy - r / 4, HMI_FormatReal(Value, Decimals), r * 42 / 100, HMI_FONT#Bold, HMI_ALIGN#Center, COLOR.Text);
    HMI_Text(cx, cy + r * 28 / 100, Unit, r * 22 / 100, HMI_FONT#Regular, HMI_ALIGN#Center, COLOR.TextMuted);
    HMI_Text(cx, Top + Height - Sc(18), Caption, Sc(14), HMI_FONT#Regular, HMI_ALIGN#Center, COLOR.TextMuted);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Vertical level bar with the value and a caption. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiTank EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    MinValue : REAL := 0.0;
    MaxValue : REAL := 100.0;
    Decimals : INT := 1;
    Unit : STRING(16);
    Caption : STRING(64) := 'Tank';
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Accent;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 80;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 200;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR ih, lh : DINT; text : STRING(65); END_VAR
    ih := MAX(Height - Sc(28), 0);
    lh := ih * HMI_PerMille(Value, MinValue, MaxValue) / 1000;
    HMI_FillRect(Left, Top, Width, ih, Sc(12), COLOR.Fill);
    HMI_Clip(Left, Top + ih - lh, Width, lh);
    HMI_FillRect(Left, Top, Width, ih, Sc(12), AccentColor);
    HMI_Unclip();
    HMI_StrokeRect(Left, Top, Width, ih, Sc(12), Sc(2), COLOR.Border);
    text := HMI_FormatValue(Value, Decimals, Unit);
    HMI_Clip(Left, Top, Width, ih - lh);
    HMI_TextBox(Left, Top, Width, ih, text, Sc(18), HMI_FONT#Bold, HMI_ALIGN#Center, HMI_VALIGN#Middle, COLOR.Text);
    HMI_Clip(Left, Top + ih - lh, Width, lh);
    HMI_TextBox(Left, Top, Width, ih, text, Sc(18), HMI_FONT#Bold, HMI_ALIGN#Center, HMI_VALIGN#Middle, COLOR.OnAccent);
    HMI_Unclip();
    HMI_Text(Left + Width / 2, Top + Height - Sc(20), Caption, Sc(14), HMI_FONT#Regular, HMI_ALIGN#Center,
      COLOR.TextMuted);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Base of the plots: the card, the grid, value-to-screen mapping and polylines of any length, drawn as runs of at
   most 64 points, the core's polygon limit, each starting where the last ended. *)
FUNCTION_BLOCK ABSTRACT HmiPlotBase EXTENDS HmiElement
  VAR
    lineColor : UDINT;
    lineWidth, lineX, lineY : DINT;
    linePoints : INT;
  END_VAR
  (* The plot's card over the whole element, corners of radius R. *)
  METHOD PROTECTED Panel : BOOL
    VAR_INPUT R : DINT; END_VAR
    HMI_FillRect(Left, Top, Width, Height, R, COLOR.Surface);
    HMI_StrokeRect(Left, Top, Width, Height, R, Sc(1), COLOR.Border);
    Panel := TRUE;
  END_METHOD
  (* Rows + 1 horizontal grid lines over the plot area, top to bottom. *)
  METHOD PROTECTED Grid : BOOL
    VAR_INPUT PX, PY, PW, PH, Rows : DINT; END_VAR
    VAR g : DINT; END_VAR
    FOR g := 0 TO Rows DO
      HMI_Line(PX, PY + PH * g / Rows, PX + PW, PY + PH * g / Rows, Sc(1), COLOR.Fill);
    END_FOR;
    Grid := TRUE;
  END_METHOD
  (* Screen Y of V on a plot area from PY, PH high, showing Lo to Hi. *)
  METHOD PROTECTED MapY : DINT
    VAR_INPUT V, Lo, Hi : REAL; PY, PH : DINT; END_VAR
    MapY := PY + PH - PH * HMI_PerMille(V, Lo, Hi) / 1000;
  END_METHOD
  (* Screen X of V on a plot area from PX, PW wide, showing Lo to Hi. *)
  METHOD PROTECTED MapX : DINT
    VAR_INPUT V, Lo, Hi : REAL; PX, PW : DINT; END_VAR
    MapX := PX + PW * HMI_PerMille(V, Lo, Hi) / 1000;
  END_METHOD
  (* Starts a polyline in colour C, W wide; LinePoint adds its points, LineEnd draws what is left. *)
  METHOD PROTECTED LineBegin : BOOL
    VAR_INPUT C : UDINT; W : DINT; END_VAR
    lineColor := C;
    lineWidth := W;
    linePoints := 0;
    LineBegin := TRUE;
  END_METHOD
  METHOD PROTECTED LinePoint : BOOL
    VAR_INPUT X, Y : DINT; END_VAR
    IF linePoints = 0 THEN
      HMI_PolyBegin(lineColor);
    ELSIF linePoints >= 64 THEN
      HMI_PolyStroke(lineWidth, FALSE);
      HMI_PolyBegin(lineColor);
      HMI_PolyPoint(lineX, lineY);
      linePoints := 1;
    END_IF;
    HMI_PolyPoint(X, Y);
    linePoints := linePoints + 1;
    lineX := X;
    lineY := Y;
    LinePoint := TRUE;
  END_METHOD
  METHOD PROTECTED LineEnd : BOOL
    IF linePoints >= 2 THEN
      HMI_PolyStroke(lineWidth, FALSE);
    END_IF;
    linePoints := 0;
    LineEnd := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Time graph of up to 8 series, Value then Value2 to Value8 as Pens counts them, each in its colour, sampled every
   SampleMs into 120 points. History starts with the screen and is not logged. *)
{attribute 'hmi_palette' := 'Display'}
{attribute 'hmi_default' := 'AutoSize := TRUE'}
FUNCTION_BLOCK HmiTrend EXTENDS HmiPlotBase
  VAR_INPUT
    (* Series 1; series 2 to 8 are Value2 to Value8, drawn while Pens counts them. *)
    {attribute 'hmi_main'}
    {attribute 'hmi_series' := 'value'}
    Value : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value2 : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value3 : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value4 : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value5 : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value6 : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value7 : REAL;
    {attribute 'hmi_group' := 'data'}
    {attribute 'hmi_series' := 'value'}
    Value8 : REAL;
    (* Number of series drawn, 1 to 8. *)
    {attribute 'hmi_series' := 'count'}
    Pens : INT := 1;
    MinValue : REAL := 0.0;
    MaxValue : REAL := 100.0;
    AutoRange : BOOL;
    SampleMs : UDINT := 1000;
    Caption : STRING(64);
    Decimals : INT := 1;
    Unit : STRING(16);
    (* Colour of series 1 and of the caption's value; series 2 to 8 take Color2 to Color8. *)
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    AccentColor : UDINT := COLOR.Accent;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color2 : UDINT := COLOR.Success;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color3 : UDINT := COLOR.Warning;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color4 : UDINT := COLOR.Danger;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color5 : UDINT := COLOR.Blue;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color6 : UDINT := COLOR.Orange;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color7 : UDINT := COLOR.Gray;
    {attribute 'hmi_color'}
    {attribute 'hmi_series' := 'color'}
    Color8 : UDINT := COLOR.Text;
  END_VAR
  VAR
    (* 120 samples per series, series after series. *)
    s : ARRAY[0..959] OF REAL;
    head, count : INT;
    lastMs : UDINT;
    started : BOOL;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 280;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 160;
  END_METHOD
  METHOD INTERNAL PenCount : INT
    PenCount := LIMIT(1, Pens, 8);
  END_METHOD
  METHOD INTERNAL PenValue : REAL
    VAR_INPUT P : INT; END_VAR
    CASE P OF
      2: PenValue := Value2;
      3: PenValue := Value3;
      4: PenValue := Value4;
      5: PenValue := Value5;
      6: PenValue := Value6;
      7: PenValue := Value7;
      8: PenValue := Value8;
    ELSE
      PenValue := Value;
    END_CASE;
  END_METHOD
  METHOD INTERNAL PenColor : UDINT
    VAR_INPUT P : INT; END_VAR
    CASE P OF
      2: PenColor := Color2;
      3: PenColor := Color3;
      4: PenColor := Color4;
      5: PenColor := Color5;
      6: PenColor := Color6;
      7: PenColor := Color7;
      8: PenColor := Color8;
    ELSE
      PenColor := AccentColor;
    END_CASE;
  END_METHOD
  METHOD INTERNAL Sample : BOOL
    VAR now : UDINT; p : INT; END_VAR
    now := HMI_TimeMs();
    IF started AND now - lastMs < SampleMs THEN
      RETURN;
    END_IF;
    started := TRUE;
    lastMs := now;
    FOR p := 1 TO 8 DO
      s[(p - 1) * 120 + head] := PenValue(p);
    END_FOR;
    head := (head + 1) MOD 120;
    IF count < 120 THEN
      count := count + 1;
    END_IF;
    Sample := TRUE;
  END_METHOD
  (* One pen over the samples, oldest first. *)
  METHOD INTERNAL Pen : BOOL
    VAR_INPUT Which : INT; Lo, Hi : REAL; PX, PY, PW, PH : DINT; C : UDINT; END_VAR
    VAR i, idx : INT; END_VAR
    IF count < 2 THEN
      RETURN;
    END_IF;
    LineBegin(C, Sc(2));
    FOR i := 0 TO count - 1 DO
      idx := (head - count + i + 240) MOD 120;
      LinePoint(PX + PW * INT_TO_DINT(i) / 119, MapY(s[(Which - 1) * 120 + idx], Lo, Hi, PY, PH));
    END_FOR;
    LineEnd();
    Pen := TRUE;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR lo, hi : REAL; i, k, p : INT; px, py, pw, ph, capH : DINT; END_VAR
    Sample();
    lo := MinValue;
    hi := MaxValue;
    IF AutoRange AND count > 0 THEN
      lo := s[(head + 119) MOD 120];
      hi := lo;
      FOR i := 0 TO count - 1 DO
        k := (head - count + i + 240) MOD 120;
        FOR p := 1 TO PenCount() DO
          lo := MIN(lo, s[(p - 1) * 120 + k]);
          hi := MAX(hi, s[(p - 1) * 120 + k]);
        END_FOR;
      END_FOR;
      IF hi - lo < 0.0001 THEN
        hi := lo + 1.0;
      END_IF;
    END_IF;
    Panel(Sc(8));
    IF LEN(Caption) > 0 THEN
      capH := Sc(20);
      HMI_Text(Left + Sc(10), Top + Sc(6), Caption, Sc(12), HMI_FONT#Regular, HMI_ALIGN#Left, COLOR.TextMuted);
      HMI_Text(Left + Width - Sc(10), Top + Sc(6), HMI_FormatValue(Value, Decimals, Unit), Sc(12), HMI_FONT#Bold,
        HMI_ALIGN#Right, AccentColor);
    END_IF;
    px := Left + Sc(44);
    py := Top + Sc(10) + capH;
    pw := Width - Sc(54);
    ph := Height - Sc(20) - capH;
    IF pw < Sc(8) OR ph < Sc(8) THEN
      Draw := TRUE;
      RETURN;
    END_IF;
    Grid(px, py, pw, ph, 4);
    HMI_Text(px - Sc(6), py - Sc(6), HMI_FormatReal(hi, Decimals), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Right,
      COLOR.TextMuted);
    HMI_Text(px - Sc(6), py + ph - Sc(6), HMI_FormatReal(lo, Decimals), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Right,
      COLOR.TextMuted);
    HMI_Clip(px, py - Sc(2), pw + Sc(1), ph + Sc(4));
    FOR p := 1 TO PenCount() DO
      Pen(p, lo, hi, px, py, pw, ph, PenColor(p));
    END_FOR;
    HMI_Unclip();
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Framed number with a unit, the small readouts of process diagrams; Caption is drawn above when set. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiReadout EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    Decimals : INT := 1;
    Unit : STRING(16);
    Caption : STRING(64);
    Size : DINT := 12;
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Accent;
  END_VAR
  (* Height of the caption band at natural size. *)
  METHOD INTERNAL NaturalCapH : DINT
    IF LEN(Caption) > 0 THEN
      NaturalCapH := Size + 4;
    END_IF;
  END_METHOD
  METHOD INTERNAL CapH : DINT
    CapH := Sc(NaturalCapH());
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := MAX(MAX(HMI_TextWidth(HMI_FormatValue(Value, Decimals, Unit), Size, HMI_FONT#Regular),
      HMI_TextWidth(Caption, Size, HMI_FONT#Bold)) + 14, 56);
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := Size + 8 + NaturalCapH();
  END_METHOD
  (* With a preferred width, the natural width without the value, so a changing value keeps the scale; else the
     natural width the box follows. *)
  METHOD PROTECTED OVERRIDE ScaleWidth : DINT
    IF PrefWidth > 0 THEN
      ScaleWidth := MAX(HMI_TextWidth(Caption, Size, HMI_FONT#Bold) + 14, 56);
    ELSE
      ScaleWidth := NaturalWidth();
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE PortY : DINT
    VAR_INPUT Port : HMI_PORT; END_VAR
    IF Port = HMI_PORT#Top THEN
      PortY := Top + CapH();
    ELSIF Port = HMI_PORT#Bottom THEN
      PortY := Top + Height;
    ELSE
      PortY := Top + CapH() + (Height - CapH()) / 2;
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR boxTop : DINT; text : STRING(65); END_VAR
    boxTop := Top + CapH();
    text := HMI_FormatValue(Value, Decimals, Unit);
    IF LEN(Caption) > 0 THEN
      HMI_Text(Left + Width / 2, Top, Caption, Sc(Size), HMI_FONT#Bold, HMI_ALIGN#Center, COLOR.Text);
    END_IF;
    HMI_FillRect(Left, boxTop, Width, Height - CapH(), Sc(2), COLOR.Surface);
    HMI_StrokeRect(Left, boxTop, Width, Height - CapH(), Sc(2), Sc(1), COLOR.Border);
    HMI_TextBox(Left, boxTop, Width, Height - CapH(), text, FitSize(text, Sc(Size), HMI_FONT#Regular, Width - Sc(4)),
      HMI_FONT#Regular, HMI_ALIGN#Center, HMI_VALIGN#Middle, AccentColor);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Vertical tank with its label block (caption, level, rate): a steel shell with a domed top on two legs, the level in a
   sight glass, and the capacity on the shell. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiVessel EXTENDS HmiSymbol
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    MinValue : REAL := 0.0;
    MaxValue : REAL := 100.0;
    Decimals : INT := 1;
    Unit : STRING(16);
    Caption : STRING(64) := 'Vessel';
    (* Second readout under the level, shown when RateUnit is set. *)
    {attribute 'hmi_group' := 'data'}
    Rate : REAL;
    RateUnit : STRING(16);
    Capacity : STRING(32);
    ShowLabels : BOOL := TRUE;
    {attribute 'hmi_color'}
    Fill : UDINT := COLOR.Fill;
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Accent;
  END_VAR
  (* Height of the label block at natural size. *)
  METHOD INTERNAL NaturalLabelH : DINT
    IF NOT ShowLabels THEN
      NaturalLabelH := 0;
    ELSIF LEN(RateUnit) > 0 THEN
      NaturalLabelH := 52;
    ELSE
      NaturalLabelH := 35;
    END_IF;
  END_METHOD
  METHOD INTERNAL LabelH : DINT
    LabelH := Sc(NaturalLabelH());
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 64;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := NaturalLabelH() + 107;
  END_METHOD
  (* Fits the drawing, 80 x 134 reference units, under the label block. *)
  METHOD INTERNAL Layout : BOOL
    Fit(800, 1340, Left, Top + LabelH(), Width, Height - LabelH(), FALSE, FALSE);
    Layout := TRUE;
  END_METHOD
  (* Ports sit on the shell: the top of the dome, the bottom between the legs and halfway up each side. *)
  METHOD PROTECTED OVERRIDE PortX : DINT
    VAR_INPUT Port : HMI_PORT; END_VAR
    Layout();
    IF Port = HMI_PORT#Left THEN
      PortX := PX(100, 700);
    ELSIF Port = HMI_PORT#Right THEN
      PortX := PX(700, 700);
    ELSE
      PortX := PX(400, 700);
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE PortY : DINT
    VAR_INPUT Port : HMI_PORT; END_VAR
    Layout();
    IF Port = HMI_PORT#Top THEN
      PortY := PY(400, 60);
    ELSIF Port = HMI_PORT#Bottom THEN
      PortY := PY(400, 1220);
    ELSE
      PortY := PY(400, 700);
    END_IF;
  END_METHOD
  METHOD INTERNAL Badge : BOOL
    VAR_INPUT BoxY : DINT; Txt : STRING; END_VAR
    VAR bw : DINT; END_VAR
    bw := MAX(HMI_TextWidth(Txt, Sc(11), HMI_FONT#Regular) + Sc(12), Sc(58));
    HMI_FillRect(Left + (Width - bw) / 2, BoxY, bw, Sc(15), Sc(1), COLOR.Surface);
    HMI_StrokeRect(Left + (Width - bw) / 2, BoxY, bw, Sc(15), Sc(1), Sc(1), COLOR.Border);
    HMI_TextBox(Left, BoxY, Width, Sc(15), Txt, Sc(11), HMI_FONT#Regular, HMI_ALIGN#Center, HMI_VALIGN#Middle,
      AccentColor);
    Badge := TRUE;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR pm, ly, k, bw, cx, cy, rx, nk : DINT; END_VAR
    IF ShowLabels THEN
      HMI_Text(Left + Width / 2, Top, Caption, Sc(12), HMI_FONT#Bold, HMI_ALIGN#Center, COLOR.Text);
      Badge(Top + Sc(17), HMI_FormatValue(Value, Decimals, Unit));
      IF LEN(RateUnit) > 0 THEN
        Badge(Top + Sc(34), HMI_FormatValue(Rate, Decimals, RateUnit));
      END_IF;
    END_IF;
    Layout();
    Part(160, 1180, 80, 160, 10, COLOR.Gray, TRUE);
    Part(560, 1180, 80, 160, 10, COLOR.Gray, TRUE);
    rx := (PX(700, 300) - PX(100, 300)) / 2;
    cx := PX(100, 300) + rx;
    HMI_FillRect(cx - rx, PY(0, 300), 2 * rx, PY(0, 1220) - PY(0, 300), 0, Fill);
    HMI_StrokeRect(cx - rx, PY(0, 300), 2 * rx, PY(0, 1220) - PY(0, 300), 0, Stroke(), COLOR.Text);
    HMI_FillEllipse(cx, PY(400, 300), rx, PL(240), COLOR.Text);
    HMI_FillEllipse(cx, PY(400, 300), MAX(rx - Stroke(), 0), MAX(PL(240) - Stroke(), 0), Fill);
    HMI_FillRect(PX(100, 300) + Stroke(), PY(400, 300), 2 * rx - 2 * Stroke(), PL(250), 0, Fill);
    Part(160, 240, 50, 940, 25, HMI_Alpha(COLOR.White, 55), FALSE);
    Part(320, 340, 160, 840, 30, COLOR.Surface, TRUE);
    pm := HMI_PerMille(Value, MinValue, MaxValue);
    IF pm > 0 THEN
      ly := 1170 - 820 * pm / 1000;
      Part(335, ly, 130, 1170 - ly, 20, AccentColor, FALSE);
    END_IF;
    FOR k := 1 TO 4 DO
      Seg(500, 340 + 840 * k / 5, 540, 340 + 840 * k / 5, 12, COLOR.Text);
    END_FOR;
    IF LEN(Capacity) > 0 THEN
      cx := PX(400, 0);
      cy := PY(0, 1100);
      nk := FitScale(800, 1340, 64, 107, FALSE);
      bw := HMI_TextWidth(Capacity, FitLen(9, nk), HMI_FONT#Regular) + FitLen(8, nk);
      HMI_FillRect(cx - bw / 2, cy - FitLen(6, nk), bw, FitLen(12, nk), FitLen(1, nk), COLOR.Surface);
      HMI_TextBox(cx - bw / 2, cy - FitLen(6, nk), bw, FitLen(12, nk), Capacity, FitLen(9, nk), HMI_FONT#Regular,
        HMI_ALIGN#Center, HMI_VALIGN#Middle, COLOR.Text);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Lamp for a state number: the light takes the state's colour and the state's name is shown under the caption. States
   lists the names, separated by semicolons, from state 0; Color0 to Color5 colour states 0 to 5. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiMultiLamp EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    {attribute 'hmi_preview' := '1'}
    Value : INT;
    Caption : STRING(64) := 'Status';
    States : STRING(160) := 'Stopped;Running;Fault';
    (* State that flashes twice a second; -1 for none. *)
    BlinkState : INT := -1;
    {attribute 'hmi_color'}
    Color0 : UDINT := COLOR.Gray;
    {attribute 'hmi_color'}
    Color1 : UDINT := COLOR.Success;
    {attribute 'hmi_color'}
    Color2 : UDINT := COLOR.Danger;
    {attribute 'hmi_color'}
    Color3 : UDINT := COLOR.Warning;
    {attribute 'hmi_color'}
    Color4 : UDINT := COLOR.Accent;
    {attribute 'hmi_color'}
    Color5 : UDINT := COLOR.Text;
  END_VAR
  (* Name of state I, empty past the last one. *)
  METHOD INTERNAL StateName : STRING(64)
    VAR_INPUT I : INT; END_VAR
    StateName := HMI_ListItem(States, I);
  END_METHOD
  METHOD INTERNAL StateColor : UDINT
    VAR_INPUT I : INT; END_VAR
    CASE I OF
      0: StateColor := Color0;
      1: StateColor := Color1;
      2: StateColor := Color2;
      3: StateColor := Color3;
      4: StateColor := Color4;
      5: StateColor := Color5;
    ELSE
      StateColor := COLOR.Border;
    END_CASE;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := MAX(HMI_TextWidth(Caption, 15, HMI_FONT#Regular), HMI_TextWidth(StateName(Value), 12, HMI_FONT#Bold))
      + 52;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 40;
  END_METHOD
  (* With a preferred width, the natural width of the caption alone, so a changing state keeps the scale; else the
     natural width the box follows. *)
  METHOD PROTECTED OVERRIDE ScaleWidth : DINT
    IF PrefWidth > 0 THEN
      ScaleWidth := HMI_TextWidth(Caption, 15, HMI_FONT#Regular) + 52;
    ELSE
      ScaleWidth := NaturalWidth();
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR d, r, cx, cy : DINT; c : UDINT; lit : BOOL; END_VAR
    d := MIN(Height, Sc(40));
    r := MAX(d / 2 - Sc(5), Sc(2));
    cx := Left + d / 2;
    cy := Top + Height / 2;
    c := StateColor(Value);
    lit := NOT (Value = BlinkState AND (HMI_TimeMs() / 250) MOD 2 = 1);
    IF lit THEN
      HMI_FillCircle(cx, cy, r + Sc(4), HMI_Alpha(c, 15));
      HMI_FillCircle(cx, cy, r, c);
    ELSE
      HMI_FillCircle(cx, cy, r, COLOR.Border);
    END_IF;
    HMI_Text(Left + d + Sc(8), cy - Sc(18), Caption, Sc(15), HMI_FONT#Regular, HMI_ALIGN#Left, COLOR.Text);
    HMI_Text(Left + d + Sc(8), cy + Sc(1), StateName(Value),
      FitSize(StateName(Value), Sc(12), HMI_FONT#Bold, Width - d - Sc(8)), HMI_FONT#Bold, HMI_ALIGN#Left, c);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Bar graph of Value between MinValue and MaxValue with a scale: along the width for Row, a level meter for Column.
   Values below LowZone or above HighZone are drawn in LowColor or HighColor, over their shaded zones; a zone whose
   limit is outside the range is off. Setpoint is marked when ShowSetpoint. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiBarGraph EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    MinValue : REAL := 0.0;
    MaxValue : REAL := 100.0;
    Decimals : INT := 1;
    Unit : STRING(16);
    Caption : STRING(64) := 'Level';
    Orientation : HMI_DIRECTION := HMI_DIRECTION#Row;
    {attribute 'hmi_group' := 'data'}
    Setpoint : REAL;
    ShowSetpoint : BOOL;
    LowZone : REAL := -1.0E38;
    HighZone : REAL := 1.0E38;
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Accent;
    {attribute 'hmi_color'}
    LowColor : UDINT := COLOR.Warning;
    {attribute 'hmi_color'}
    HighColor : UDINT := COLOR.Danger;
  END_VAR
  METHOD INTERNAL Vertical : BOOL
    Vertical := Orientation = HMI_DIRECTION#Column;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := SEL(Vertical(), 200, 72);
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := SEL(Vertical(), 60, 180);
  END_METHOD
  (* Fill colour of the bar for the current value. *)
  METHOD INTERNAL BarColor : UDINT
    BarColor := AccentColor;
    IF Value < LowZone AND LowZone > MinValue THEN
      BarColor := LowColor;
    ELSIF Value > HighZone AND HighZone < MaxValue THEN
      BarColor := HighColor;
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR x, y, w, h, pm, k, t, p : DINT; txt : STRING(65); END_VAR
    txt := HMI_FormatValue(Value, Decimals, Unit);
    pm := HMI_PerMille(Value, MinValue, MaxValue);
    IF NOT Vertical() THEN
      HMI_Text(Left, Top, Caption, Sc(12), HMI_FONT#Regular, HMI_ALIGN#Left, COLOR.TextMuted);
      HMI_Text(Left + Width, Top, txt, Sc(12), HMI_FONT#Bold, HMI_ALIGN#Right, COLOR.Text);
      x := Left;
      y := Top + Sc(18);
      w := Width;
      h := Sc(14);
      HMI_FillRect(x, y, w, h, Sc(3), COLOR.Fill);
      IF LowZone > MinValue AND LowZone < MaxValue THEN
        HMI_FillRect(x, y, w * HMI_PerMille(LowZone, MinValue, MaxValue) / 1000, h, Sc(3), HMI_Alpha(LowColor, 25));
      END_IF;
      IF HighZone > MinValue AND HighZone < MaxValue THEN
        p := w * HMI_PerMille(HighZone, MinValue, MaxValue) / 1000;
        HMI_FillRect(x + p, y, w - p, h, Sc(3), HMI_Alpha(HighColor, 25));
      END_IF;
      IF pm > 0 THEN
        HMI_FillRect(x, y, MAX(w * pm / 1000, Sc(6)), h, Sc(3), BarColor());
      END_IF;
      IF ShowSetpoint THEN
        p := x + w * HMI_PerMille(Setpoint, MinValue, MaxValue) / 1000;
        HMI_FillRect(p - Sc(1), y - Sc(4), Sc(3), h + Sc(8), Sc(1), COLOR.Text);
      END_IF;
      FOR k := 0 TO 10 DO
        t := SEL(k MOD 5 = 0, Sc(4), Sc(7));
        HMI_FillRect(x + w * k / 10 - SEL(k = 10, 0, Sc(1)), y + h + Sc(3), Sc(1), t, 0, COLOR.TextMuted);
      END_FOR;
      HMI_Text(x, y + h + Sc(12), HMI_FormatReal(MinValue, 0), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Left,
        COLOR.TextMuted);
      HMI_Text(x + w / 2, y + h + Sc(12), HMI_FormatReal((MinValue + MaxValue) / 2.0, 0), Sc(10), HMI_FONT#Regular,
        HMI_ALIGN#Center, COLOR.TextMuted);
      HMI_Text(x + w, y + h + Sc(12), HMI_FormatReal(MaxValue, 0), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Right,
        COLOR.TextMuted);
    ELSE
      HMI_Text(Left + Width / 2, Top, Caption, Sc(12), HMI_FONT#Regular, HMI_ALIGN#Center, COLOR.TextMuted);
      HMI_Text(Left + Width / 2, Top + Height - Sc(15), txt, Sc(12), HMI_FONT#Bold, HMI_ALIGN#Center, COLOR.Text);
      w := Sc(16);
      x := Left + Width / 2 - w - Sc(2);
      y := Top + Sc(20);
      h := MAX(Height - Sc(42), Sc(10));
      HMI_FillRect(x, y, w, h, Sc(3), COLOR.Fill);
      IF LowZone > MinValue AND LowZone < MaxValue THEN
        p := h * HMI_PerMille(LowZone, MinValue, MaxValue) / 1000;
        HMI_FillRect(x, y + h - p, w, p, Sc(3), HMI_Alpha(LowColor, 25));
      END_IF;
      IF HighZone > MinValue AND HighZone < MaxValue THEN
        p := h * HMI_PerMille(HighZone, MinValue, MaxValue) / 1000;
        HMI_FillRect(x, y, w, h - p, Sc(3), HMI_Alpha(HighColor, 25));
      END_IF;
      IF pm > 0 THEN
        p := MAX(h * pm / 1000, Sc(6));
        HMI_FillRect(x, y + h - p, w, p, Sc(3), BarColor());
      END_IF;
      IF ShowSetpoint THEN
        p := y + h - h * HMI_PerMille(Setpoint, MinValue, MaxValue) / 1000;
        HMI_FillRect(x - Sc(4), p - Sc(1), w + Sc(8), Sc(3), Sc(1), COLOR.Text);
      END_IF;
      FOR k := 0 TO 10 DO
        t := SEL(k MOD 5 = 0, Sc(4), Sc(7));
        HMI_FillRect(x + w + Sc(3), y + h - h * k / 10 - SEL(k = 10, 0, Sc(1)), t, Sc(1), 0, COLOR.TextMuted);
      END_FOR;
      HMI_Text(x + w + Sc(12), y + h - Sc(6), HMI_FormatReal(MinValue, 0), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Left,
        COLOR.TextMuted);
      HMI_Text(x + w + Sc(12), y - Sc(6), HMI_FormatReal(MaxValue, 0), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Left,
        COLOR.TextMuted);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Progress bar of Value from 0 to MaxValue, with the percentage when ShowPercent. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiProgress EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    MaxValue : REAL := 100.0;
    Caption : STRING(64) := 'Progress';
    ShowPercent : BOOL := TRUE;
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Accent;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 200;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 30;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR pm, y : DINT; END_VAR
    pm := HMI_PerMille(Value, 0.0, MaxValue);
    HMI_Text(Left, Top, Caption, Sc(12), HMI_FONT#Regular, HMI_ALIGN#Left, COLOR.TextMuted);
    IF ShowPercent THEN
      HMI_Text(Left + Width, Top, CONCAT(HMI_FormatInt(pm / 10), ' %'), Sc(12), HMI_FONT#Bold, HMI_ALIGN#Right,
        COLOR.Text);
    END_IF;
    y := Top + Height - Sc(8);
    HMI_FillRect(Left, y, Width, Sc(8), Sc(4), COLOR.Fill);
    IF pm > 0 THEN
      HMI_FillRect(Left, y, MAX(Width * pm / 1000, Sc(8)), Sc(8), Sc(4), AccentColor);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Small indicator light for dense panels, with an optional caption. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiLed EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : BOOL;
    Caption : STRING(64) := 'LED';
    (* Flashes twice a second while on. *)
    Blink : BOOL;
    {attribute 'hmi_color'}
    OnColor : UDINT := COLOR.Success;
    {attribute 'hmi_color'}
    OffColor : UDINT := COLOR.Fill;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 18;
    IF LEN(Caption) > 0 THEN
      NaturalWidth := HMI_TextWidth(Caption, 12, HMI_FONT#Regular) + 24;
    END_IF;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 18;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR cx, cy : DINT; lit : BOOL; END_VAR
    cx := Left + Sc(9);
    cy := Top + Height / 2;
    lit := Value AND NOT (Blink AND (HMI_TimeMs() / 250) MOD 2 = 1);
    IF lit THEN
      HMI_FillCircle(cx, cy, Sc(7), OnColor);
      HMI_FillCircle(cx - Sc(2), cy - Sc(2), Sc(2), HMI_Alpha(COLOR.White, 60));
    ELSE
      HMI_FillCircle(cx, cy, Sc(7), COLOR.Border);
      HMI_FillCircle(cx, cy, Sc(7) - Sc(1), OffColor);
    END_IF;
    IF LEN(Caption) > 0 THEN
      HMI_TextBox(Left + Sc(22), Top, Width - Sc(22), Height, Caption, Sc(12), HMI_FONT#Regular, HMI_ALIGN#Left,
        HMI_VALIGN#Middle, COLOR.Text);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Seven-segment display of Value with Decimals decimals in Digits places, right aligned; dashes when it does not fit. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiSevenSegment EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    Digits : INT := 4;
    Decimals : INT := 1;
    {attribute 'hmi_color'}
    OnColor : UDINT := 16#FF4B2B;
    {attribute 'hmi_color'}
    OffColor : UDINT := 16#1E2630;
    {attribute 'hmi_color'}
    Background : UDINT := 16#0B0F14;
  END_VAR
  METHOD INTERNAL Count : INT
    Count := LIMIT(1, Digits, 12);
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := Count() * 22 + 14;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 44;
  END_METHOD
  (* One segment from (X1, Y1) to (X2, Y2), horizontal or vertical, T thick, with pointed ends. *)
  METHOD INTERNAL Segment : BOOL
    VAR_INPUT X1, Y1, X2, Y2, T : DINT; C : UDINT; END_VAR
    VAR h : DINT; END_VAR
    h := MAX(T / 2, 1);
    HMI_PolyBegin(C);
    IF Y1 = Y2 THEN
      HMI_PolyPoint(X1, Y1);
      HMI_PolyPoint(X1 + h, Y1 - h);
      HMI_PolyPoint(X2 - h, Y1 - h);
      HMI_PolyPoint(X2, Y1);
      HMI_PolyPoint(X2 - h, Y1 + h);
      HMI_PolyPoint(X1 + h, Y1 + h);
    ELSE
      HMI_PolyPoint(X1, Y1);
      HMI_PolyPoint(X1 + h, Y1 + h);
      HMI_PolyPoint(X1 + h, Y2 - h);
      HMI_PolyPoint(X1, Y2);
      HMI_PolyPoint(X1 - h, Y2 - h);
      HMI_PolyPoint(X1 - h, Y1 + h);
    END_IF;
    HMI_PolyFill();
    Segment := TRUE;
  END_METHOD
  (* Segments a b c d e f g of character Ch as bits 0 to 6. *)
  METHOD INTERNAL Mask : DINT
    VAR_INPUT Ch : STRING(1); END_VAR
    VAR glyphs : STRING(11) := '0123456789-'; END_VAR
    CASE FIND(glyphs, Ch) OF
      1: Mask := 16#3F;
      2: Mask := 16#06;
      3: Mask := 16#5B;
      4: Mask := 16#4F;
      5: Mask := 16#66;
      6: Mask := 16#6D;
      7: Mask := 16#7D;
      8: Mask := 16#07;
      9: Mask := 16#7F;
      10: Mask := 16#6F;
      11: Mask := 16#40;
    ELSE
      Mask := 0;
    END_CASE;
  END_METHOD
  (* Character I of the digit cells, counted from the left, and whether a decimal point follows it. *)
  METHOD INTERNAL Cell : STRING(1)
    VAR_INPUT Text : STRING(48); I : DINT; END_VAR
    VAR k, n : DINT; c : STRING(1); END_VAR
    n := 0;
    Cell := ' ';
    FOR k := 1 TO LEN(Text) DO
      c := MID(Text, 1, k);
      IF c <> '.' THEN
        IF n = I THEN
          Cell := c;
        END_IF;
        n := n + 1;
      END_IF;
    END_FOR;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR text, raw : STRING(48); n, cells, i, k, s, x, y0, ym, y1, w, t, dot, m, g : DINT; c : UDINT; END_VAR
    n := Count();
    HMI_FillRect(Left, Top, Width, Height, Sc(6), Background);
    raw := HMI_FormatReal(Value, LIMIT(0, Decimals, 6));
    cells := 0;
    dot := -1;
    FOR k := 1 TO LEN(raw) DO
      IF MID(raw, 1, k) = '.' THEN
        dot := cells - 1;
      ELSE
        cells := cells + 1;
      END_IF;
    END_FOR;
    text := raw;
    IF cells > n THEN
      text := '';
      FOR k := 1 TO n DO
        text := CONCAT(text, '-');
      END_FOR;
      dot := -1;
      cells := n;
    END_IF;
    s := MAX(MIN((Width - Sc(14)) / n, Height * 22 / 44), Sc(4));
    w := s * 6 / 22;
    t := MAX(s * 3 / 22, Sc(2));
    g := MAX(s / 11, Sc(1));
    y0 := Top + (Height - s * 28 / 22) / 2;
    ym := y0 + s * 14 / 22;
    y1 := y0 + s * 28 / 22;
    x := Left + Width - Sc(7) - n * s + s * 3 / 22;
    FOR i := 0 TO n - 1 DO
      m := 0;
      IF i >= n - cells THEN
        m := Mask(Cell(text, i - (n - cells)));
      END_IF;
      c := SEL(m MOD 2 = 1, OffColor, OnColor);
      Segment(x + g, y0, x + w * 2 + g, y0, t, c);
      c := SEL((m / 2) MOD 2 = 1, OffColor, OnColor);
      Segment(x + w * 2 + 2 * g, y0 + g, x + w * 2 + 2 * g, ym - g, t, c);
      c := SEL((m / 4) MOD 2 = 1, OffColor, OnColor);
      Segment(x + w * 2 + 2 * g, ym + g, x + w * 2 + 2 * g, y1 - g, t, c);
      c := SEL((m / 8) MOD 2 = 1, OffColor, OnColor);
      Segment(x + g, y1, x + w * 2 + g, y1, t, c);
      c := SEL((m / 16) MOD 2 = 1, OffColor, OnColor);
      Segment(x, ym + g, x, y1 - g, t, c);
      c := SEL((m / 32) MOD 2 = 1, OffColor, OnColor);
      Segment(x, y0 + g, x, ym - g, t, c);
      c := SEL((m / 64) MOD 2 = 1, OffColor, OnColor);
      Segment(x + g, ym, x + w * 2 + g, ym, t, c);
      IF dot >= 0 AND i = dot + n - cells THEN
        HMI_FillCircle(x + w * 2 + 2 * g + t * 2, y1, MAX(t / 2 + 1, 1), OnColor);
      END_IF;
      x := x + s;
    END_FOR;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Thermometer: the column rises from the bulb with Value between MinValue and MaxValue, beside a scale. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiThermometer EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : REAL;
    MinValue : REAL := 0.0;
    MaxValue : REAL := 100.0;
    Decimals : INT := 1;
    Unit : STRING(16) := '°C';
    {attribute 'hmi_color'}
    AccentColor : UDINT := COLOR.Danger;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 72;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 160;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR cx, ytop, ybot, br, tw, h, k, y : DINT; END_VAR
    cx := Left + Sc(20);
    br := Sc(13);
    tw := Sc(16);
    ytop := Top + Sc(10);
    ybot := MAX(Top + Height - Sc(22) - br * 2, ytop + Sc(4));
    HMI_FillRect(cx - tw / 2, ytop - Sc(6), tw, ybot - ytop + Sc(18), tw / 2, COLOR.Border);
    HMI_FillRect(cx - tw / 2 + Sc(1), ytop - Sc(5), tw - Sc(2), ybot - ytop + Sc(16), tw / 2 - Sc(1), COLOR.Surface);
    HMI_FillCircle(cx, ybot + br, br, COLOR.Border);
    HMI_FillCircle(cx, ybot + br, br - Sc(1), COLOR.Surface);
    h := (ybot - ytop) * HMI_PerMille(Value, MinValue, MaxValue) / 1000;
    HMI_FillRect(cx - Sc(4), ybot - h, Sc(8), h + br, Sc(4), AccentColor);
    HMI_FillCircle(cx, ybot + br, br - Sc(4), AccentColor);
    FOR k := 0 TO 10 DO
      y := ybot - (ybot - ytop) * k / 10;
      HMI_FillRect(cx + tw / 2 + Sc(3), y, SEL(k MOD 5 = 0, Sc(4), Sc(8)), Sc(1), 0, COLOR.TextMuted);
    END_FOR;
    HMI_Text(cx + tw / 2 + Sc(14), ytop - Sc(6), HMI_FormatReal(MaxValue, 0), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Left,
      COLOR.TextMuted);
    HMI_Text(cx + tw / 2 + Sc(14), (ytop + ybot) / 2 - Sc(6), HMI_FormatReal((MinValue + MaxValue) / 2.0, 0), Sc(10),
      HMI_FONT#Regular, HMI_ALIGN#Left, COLOR.TextMuted);
    HMI_Text(cx + tw / 2 + Sc(14), ybot - Sc(6), HMI_FormatReal(MinValue, 0), Sc(10), HMI_FONT#Regular, HMI_ALIGN#Left,
      COLOR.TextMuted);
    HMI_Text(Left + Width / 2, Top + Height - Sc(16), HMI_FormatValue(Value, Decimals, Unit), Sc(13), HMI_FONT#Bold,
      HMI_ALIGN#Center, COLOR.Text);
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Date and time of a DT: the time on top, larger, and the date under it in DateStyle; either can be hidden. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiDateTime EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : DT;
    ShowTime : BOOL := TRUE;
    ShowSeconds : BOOL := TRUE;
    ShowDate : BOOL := TRUE;
    DateStyle : HMI_DATE_STYLE := HMI_DATE_STYLE#Long;
  END_VAR
  VAR
    cal : HmiCalendar;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 200;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := SEL(ShowTime AND ShowDate, 34, 56);
  END_METHOD
  (* N with two digits, or with four when Wide. *)
  METHOD INTERNAL Pad : STRING(8)
    VAR_INPUT N : DINT; Wide : BOOL; END_VAR
    Pad := HMI_FormatInt(N);
    WHILE LEN(Pad) < SEL(Wide, 2, 4) DO
      Pad := CONCAT('0', Pad);
    END_WHILE;
  END_METHOD
  METHOD INTERNAL TimeText : STRING(16)
    TimeText := CONCAT(CONCAT(Pad(cal.Hour, FALSE), ':'), Pad(cal.Minute, FALSE));
    IF ShowSeconds THEN
      TimeText := CONCAT(CONCAT(TimeText, ':'), Pad(cal.Second, FALSE));
    END_IF;
  END_METHOD
  METHOD INTERNAL DateText : STRING(32)
    VAR d, m, y : STRING(8); days : STRING(21) := 'SunMonTueWedThuFriSat'; months : STRING(36) :=
      'JanFebMarAprMayJunJulAugSepOctNovDec'; END_VAR
    d := Pad(cal.Day, FALSE);
    m := Pad(cal.Month, FALSE);
    y := Pad(cal.Year, TRUE);
    CASE DateStyle OF
      HMI_DATE_STYLE#Iso:
        DateText := CONCAT(CONCAT(CONCAT(CONCAT(y, '-'), m), '-'), d);
      HMI_DATE_STYLE#DayMonth:
        DateText := CONCAT(CONCAT(CONCAT(CONCAT(d, '/'), m), '/'), y);
      HMI_DATE_STYLE#MonthDay:
        DateText := CONCAT(CONCAT(CONCAT(CONCAT(m, '/'), d), '/'), y);
    ELSE
      DateText := CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(
        MID(days, 3, cal.WeekDay * 3 + 1), ' '), HMI_FormatInt(cal.Day)), ' '),
        MID(months, 3, (cal.Month - 1) * 3 + 1)), ' '), y);
    END_CASE;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR cx : DINT; END_VAR
    cal(Value := Value);
    cx := Left + Width / 2;
    HMI_FillRect(Left, Top, Width, Height, Sc(8), COLOR.Surface);
    HMI_StrokeRect(Left, Top, Width, Height, Sc(8), Sc(1), COLOR.Border);
    IF ShowTime AND ShowDate THEN
      HMI_TextBox(Left, Top + Sc(4), Width, Height * 6 / 10, TimeText(), Sc(22), HMI_FONT#Bold, HMI_ALIGN#Center,
        HMI_VALIGN#Middle, COLOR.Text);
      HMI_TextBox(Left, Top + Height * 6 / 10, Width, Height * 4 / 10 - Sc(4), DateText(), Sc(12), HMI_FONT#Regular,
        HMI_ALIGN#Center, HMI_VALIGN#Middle, COLOR.TextMuted);
    ELSIF ShowTime THEN
      HMI_TextBox(Left, Top, Width, Height, TimeText(), Sc(20), HMI_FONT#Bold, HMI_ALIGN#Center, HMI_VALIGN#Middle,
        COLOR.Text);
    ELSIF ShowDate THEN
      HMI_TextBox(Left, Top, Width, Height, DateText(), Sc(15), HMI_FONT#Regular, HMI_ALIGN#Center, HMI_VALIGN#Middle,
        COLOR.Text);
    END_IF;
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

(* Analog clock showing the time of day of a DT, with a second hand when ShowSeconds. *)
{attribute 'hmi_palette' := 'Display'}
FUNCTION_BLOCK HmiClock EXTENDS HmiElement
  VAR_INPUT
    {attribute 'hmi_main'}
    Value : DT;
    ShowSeconds : BOOL := TRUE;
    {attribute 'hmi_color'}
    HandColor : UDINT := COLOR.Text;
    {attribute 'hmi_color'}
    SecondColor : UDINT := COLOR.Danger;
  END_VAR
  VAR
    cal : HmiCalendar;
  END_VAR
  METHOD PROTECTED OVERRIDE NaturalWidth : DINT
    NaturalWidth := 120;
  END_METHOD
  METHOD PROTECTED OVERRIDE NaturalHeight : DINT
    NaturalHeight := 120;
  END_METHOD
  (* A hand from the centre at A degrees clockwise from twelve, L long and W wide. *)
  METHOD INTERNAL Hand : BOOL
    VAR_INPUT Cx, Cy, A, L, W : DINT; C : UDINT; END_VAR
    HMI_Line(Cx, Cy, Cx + HMI_Sin(A, L), Cy - HMI_Cos(A, L), W, C);
    HMI_FillCircle(Cx + HMI_Sin(A, L), Cy - HMI_Cos(A, L), W / 2, C);
    Hand := TRUE;
  END_METHOD
  METHOD PROTECTED OVERRIDE Draw : BOOL
    VAR cx, cy, r, k, a, r1 : DINT; big : BOOL; END_VAR
    cal(Value := Value);
    cx := Left + Width / 2;
    cy := Top + Height / 2;
    r := MAX(MIN(Width, Height) / 2 - Sc(2), Sc(8));
    HMI_FillCircle(cx, cy, r, COLOR.Border);
    HMI_FillCircle(cx, cy, r - Sc(2), COLOR.Surface);
    FOR k := 0 TO 59 DO
      a := k * 6;
      big := k MOD 5 = 0;
      r1 := r - SEL(big, r / 11, r / 5);
      HMI_Line(cx + HMI_Sin(a, r1), cy - HMI_Cos(a, r1), cx + HMI_Sin(a, r - Sc(4)), cy - HMI_Cos(a, r - Sc(4)),
        SEL(big, Sc(1), MAX(r / 25, Sc(2))), SEL(big, COLOR.TextMuted, COLOR.Text));
    END_FOR;
    Hand(cx, cy, (cal.Hour MOD 12) * 30 + cal.Minute / 2, r * 52 / 100, MAX(r / 11, Sc(3)), HandColor);
    Hand(cx, cy, cal.Minute * 6 + cal.Second / 10, r * 78 / 100, MAX(r / 15, Sc(2)), HandColor);
    IF ShowSeconds THEN
      Hand(cx, cy, cal.Second * 6, r * 85 / 100, MAX(r / 36, Sc(1)), SecondColor);
    END_IF;
    HMI_FillCircle(cx, cy, MAX(r / 13, Sc(3)), SEL(ShowSeconds, HandColor, SecondColor));
    Draw := TRUE;
  END_METHOD
END_FUNCTION_BLOCK

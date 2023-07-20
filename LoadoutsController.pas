{$WARN SYMBOL_PLATFORM OFF}
unit LoadoutsController;

interface

uses
  Classes, Types, Generics.Collections, SysUtils, Windows, Graphics,
  StateMachine;

type
  TKeyLoadouts = record
    NextIndex: Integer;
    SlotSequence: TArray<Integer>;
  end;

  TCoordinates = record
    SampleBox: TRect;
    SlotCenter: TPoint;
    SlotDistance: Integer;
    LoadoutBarLeft: Integer;
  end;

  TLoadoutState =
  ( lsIdle
  , lsPreMove
  , lsAwaitInventory
  , lsAwaitLoadouts
  , lsActivateLoadout
  , lsExitInventory
  );

  TLoadoutsController = class
  private
    keyLoadoutsTable: array[0..255] of TKeyLoadouts;
    stepper: TStateMachine<TLoadoutState>;
    appWnd: HWND;
    appRect: TRect;
    coords: TCoordinates;
    currSlotNr: Integer;
    prevSlotNr: Integer;

    procedure Step(CurrentState: TLoadoutState; StateCount: Integer;
      var NextState: TLoadoutState; var Delay: Cardinal);
    function FetchAppWnd: Boolean;
    function FetchResolutionCoordinates: Boolean;
    function GetInitialMouseTargetPos: TPoint;
    function TriggerKeyAction(VKey: Word): Boolean;
    procedure TriggerMoveAction(ScreenPos: TPoint; Delta: Integer);
    procedure TriggerClickAction;
    function CaptureScreen(const Rect: TRect): TBitmap;
    function DetectSampleBox: Boolean;
    function DetectLoadoutBar: Boolean;
    function IsGrayPixel(const Pixel: TRGBQuad; MinBright: Integer): Boolean;
    function SamePixel(const A, B: TRGBQuad): Boolean;
    function SamePixels(const A: TRGBQuad; P: PRGBQuad; Count: Integer): Boolean;
  public
    constructor Create(Machine: TStateMachine<TLoadoutState>);

    function GetLoadoutSets(const BasePath: string): TStringDynArray;
    procedure LoadLoadoutSet(const Path: string);

    procedure OnExternalKeyDown(VKey: Word);
  end;

implementation

uses
  IOUtils, Forms;

constructor TLoadoutsController.Create(Machine: TStateMachine<TLoadoutState>);
begin
  stepper := Machine;
end;

function TLoadoutsController.GetLoadoutSets(const BasePath: string): TStringDynArray;
const
  cLoadoutSetFilePattern = '*.dls';
begin
  result := TDirectory.GetFiles(BasePath, cLoadoutSetFilePattern);
  TArray.Sort<string>(result);
end;

procedure TLoadoutsController.LoadLoadoutSet(const Path: string);
var
  entries: TStringList;
  slots: TStringList;
  i, j: Integer;
  vkey: Integer;
begin
  for i := Low(keyLoadoutsTable) to High(keyLoadoutsTable) do
    keyLoadoutsTable[i] := Default(TKeyLoadouts);

  entries := TStringList.Create;
  entries.NameValueSeparator := ':';
  slots := TStringList.Create;
  try
    entries.LoadFromFile(Path, TEncoding.UTF8);
    for i := 0 to entries.Count - 1 do
    begin
      if TryStrToInt(entries.Names[i], vkey) and
        (vKey >= 0) and (vKey <= 255) then
      begin
        slots.CommaText := entries.ValueFromIndex[i];
        SetLength(keyLoadoutsTable[vkey].SlotSequence, slots.Count);
        for j := 0 to slots.Count - 1 do
          keyLoadoutsTable[vkey].SlotSequence[j] := StrToInt(slots[j]);
      end;
    end;
  finally
    slots.Free;
    entries.Free;
  end;
end;

procedure TLoadoutsController.OnExternalKeyDown(VKey: Word);
var
  slotNr: Integer;
  len: Integer;
  ix: Integer;
begin
  if (VKey > 255) or not stepper.IsIdle then
    Exit;

  len := Length(keyLoadoutsTable[VKey].SlotSequence);
  if len <= 0 then
    Exit;

  ix := keyLoadoutsTable[VKey].NextIndex;
  keyLoadoutsTable[VKey].NextIndex := (ix + 1) mod len;

  slotNr := keyLoadoutsTable[VKey].SlotSequence[ix];
  if slotNr = 0 then
    slotNr := prevSlotNr;

  if (slotNr >= 1) and (slotNr <= 10) then
  begin
    prevSlotNr := currSlotNr;
    currSlotNr := slotNr;
    stepper.Start(Step);
  end;
end;

function TLoadoutsController.FetchAppWnd: Boolean;
const
  cAppTitle = 'Destiny 2';
var
  buf: array[0..Length(cAppTitle)] of Char;
begin
  appWnd := GetForegroundWindow;
  result := (GetWindowText(appWnd, buf, Length(buf)) = Length(cAppTitle)) and
    (StrComp(buf, cAppTitle) = 0);
end;

function TLoadoutsController.FetchResolutionCoordinates: Boolean;
var
  res: TResourceStream;
  lines: TStringList;
  vect: TArray<string>;
  line: string;
  clientPos: TPoint;
  ix: Integer;
  row, col: Integer;
begin
  result := false;

  Win32Check(GetClientRect(appWnd, appRect));
  clientPos := TPoint.Zero;
  Win32Check(ClientToScreen(appWnd, clientPos));
  appRect.Offset(clientPos);

  res := TResourceStream.Create(HInstance, 'Coordinates', RT_RCDATA);
  lines := TStringList.Create;
  try
    lines.LoadFromStream(res);
    ix := lines.IndexOfName(Format('%dx%d', [appRect.Width, appRect.Height]));
    if ix >= 0 then
    begin
      line := lines.ValueFromIndex[ix];
      vect := line.Split([',']);
      result := Length(vect) = 8;
      if result then
      begin
        row := (currSlotNr - 1) div 2;
        col := (currSlotNr - 1) mod 2;

        coords.SlotCenter.X := StrToInt(vect[0]);
        coords.SlotCenter.Y := StrToInt(vect[1]);
        coords.SlotDistance := StrToInt(vect[2]);
        coords.LoadoutBarLeft := StrToInt(vect[3]);
        coords.SlotCenter.Offset(appRect.TopLeft);
        coords.SlotCenter.Offset(col * coords.SlotDistance, row * coords.SlotDistance);
        Inc(coords.LoadoutBarLeft, appRect.Left);

        coords.SampleBox.Left := StrToInt(vect[4]);
        coords.SampleBox.Top := StrToInt(vect[5]);
        coords.SampleBox.Width := StrToInt(vect[6]);
        coords.SampleBox.Height := StrToInt(vect[7]);
        coords.SampleBox.Offset(appRect.TopLeft);
      end;
    end;
  finally
    lines.Free;
    res.Free;
  end;
end;

function TLoadoutsController.TriggerKeyAction(VKey: Word): Boolean;
var
  input: array[0..1] of TInput;
begin
  ZeroMemory(@input, SizeOf(input));
  input[0].Itype := INPUT_KEYBOARD;
  input[0].ki.wVk := VKey;
  input[1].Itype := INPUT_KEYBOARD;
  input[1].ki.wVk := VKey;
  input[1].ki.dwFlags := KEYEVENTF_KEYUP;
  result := SendInput(2, input[0], SizeOf(TInput)) = 2;
end;

procedure TLoadoutsController.TriggerMoveAction(ScreenPos: TPoint; Delta: Integer);
var
  input: TInput;
  absX, absY: Integer;
begin
  ScreenPos.Offset(Delta, Delta);

  absX := (ScreenPos.X * $FFFF) div Screen.PrimaryMonitor.Width;
  absY := (ScreenPos.Y * $FFFF) div Screen.PrimaryMonitor.Height;

  ZeroMemory(@input, SizeOf(input));
  input.Itype := INPUT_MOUSE;
  input.mi.dwFlags := MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE;
  input.mi.dx := absX;
  input.mi.dy := absY;
  input.Itype := INPUT_MOUSE;
  SendInput(1, input, SizeOf(TInput));
end;

procedure TLoadoutsController.TriggerClickAction;
var
  input: array[0..1] of TInput;
begin
  ZeroMemory(@input, SizeOf(input));
  input[0].Itype := INPUT_MOUSE;
  input[0].mi.dwFlags := MOUSEEVENTF_LEFTDOWN or MOUSEEVENTF_ABSOLUTE;
  input[1].Itype := INPUT_MOUSE;
  input[1].mi.dwFlags := MOUSEEVENTF_LEFTUP or MOUSEEVENTF_ABSOLUTE;
  SendInput(2, input[0], SizeOf(TInput));
end;

function TLoadoutsController.GetInitialMouseTargetPos: TPoint;
const
  cLeftBorder = 10;
begin
  result.X := appRect.Left + cLeftBorder;
  result.Y := (appRect.Top + appRect.Bottom) div 2;
end;

function TLoadoutsController.CaptureScreen(const Rect: TRect): TBitmap;
var
  desktopDC: HDC;
begin
  desktopDC := CreateDC('DISPLAY', nil, nil, nil);
  result := TBitmap.Create(Rect.Width, Rect.Height);
  result.PixelFormat := pf32bit;
  Win32Check(BitBlt(result.Canvas.Handle, 0, 0, Rect.Width, Rect.Height, desktopDC, rect.Left, rect.Top, SRCCOPY));
  Win32Check(DeleteDC(desktopDC));
end;

function TLoadoutsController.DetectLoadoutBar: Boolean;
const
  cTolerance = 100;
  cMinBrightness = 50;
var
  box: TBitmap;
  row: PRGBQuad;
  barRect: TRect;
  ref: TRGBQuad;
  i, count: Integer;
begin
  barRect.Left := coords.LoadoutBarLeft;
  barRect.Top := appRect.Top;
  barRect.Width := 1;
  barRect.Height := appRect.Height;

  count := 0;
  box := CaptureScreen(barRect);
  try
    ref := PRGBQuad(box.ScanLine[0])^;
    if IsGrayPixel(ref, cMinBrightness) then
    begin
      for i := 1 to box.Height - 1 do
      begin
        row := PRGBQuad(box.ScanLine[i]);
        Inc(count, Ord(SamePixel(row^, ref)));
      end;
    end;
  finally
    box.Free;
  end;
  result := count + cTolerance > box.Height;
end;

function TLoadoutsController.IsGrayPixel(const Pixel: TRGBQuad; MinBright: Integer): Boolean;
const
  cDiffThreshold = 10;
begin
  result := (Pixel.rgbBlue >= MinBright) and
    (Pixel.rgbGreen >= MinBright) and
    (Pixel.rgbRed >= MinBright) and
    (Abs(Pixel.rgbBlue - Pixel.rgbGreen) <= cDiffThreshold) and
    (Abs(Pixel.rgbBlue - Pixel.rgbRed) <= cDiffThreshold) and
    (Abs(Pixel.rgbGreen - Pixel.rgbRed) <= cDiffThreshold);
end;

function TLoadoutsController.SamePixel(const A, B: TRGBQuad): Boolean;
const
  cThreshold = 12;
begin
  result := (Abs(A.rgbRed - B.rgbRed) <= cThreshold) and
    (Abs(A.rgbGreen - B.rgbGreen) <= cThreshold) and
    (Abs(A.rgbBlue - B.rgbBlue) <= cThreshold);
end;

function TLoadoutsController.SamePixels(const A: TRGBQuad; P: PRGBQuad;
  Count: Integer): Boolean;
var
  i: Integer;
begin
  result := false;
  for i := 0 to Count - 1 do
  begin
    if not SamePixel(A, P^) then
      Exit;
    Inc(P);
  end;
  result := True;
end;

function TLoadoutsController.DetectSampleBox: Boolean;
const
  cMinBrightness = 140;
var
  box: TBitmap;
  row: PRGBQuad;
  ref: TRGBQuad;
  i: Integer;
begin
  result := false;
  box := CaptureScreen(coords.SampleBox);
  try
    ref := PRGBQuad(box.ScanLine[0])^;
    if not IsGrayPixel(ref, cMinBrightness) then
      Exit;

    for i := 0 to box.Height - 1 do
    begin
      row := PRGBQuad(box.ScanLine[i]);
      if not SamePixels(ref, row, box.Width) then
        Exit;
    end;
  finally
    box.Free;
  end;
  result := true;
end;

procedure TLoadoutsController.Step(CurrentState: TLoadoutState; StateCount: Integer;
  var NextState: TLoadoutState; var Delay: Cardinal);
const
  cInventoryKey = VK_F1;
  cPreMoveDelay = 250;
  cInitialSampleDelay = 70;
  cRepeatSampleDelay = 20;
  cMaxSampleIterations = 100;
  cLoadoutsKey = VK_LEFT;
  cInitialLoadoutsDelay = 100;
  cRepeatLoadoutsDelay = 10;
  cMaxLoadoutIterations = 20;
  cInitialActivateDelay = 40;
  cRepeatActivateDelay = 10;
  cMaxActivateIterations = 50;
  cExitDelay = 20;
begin
  case CurrentState of
    lsIdle:
      if FetchAppWnd and
        FetchResolutionCoordinates and
        TriggerKeyAction(cInventoryKey) then
      begin
        NextState := lsPreMove;
        Delay := cPreMoveDelay;
      end
      else
        MessageBeep(MB_ICONWARNING);
    lsPreMove:
      begin
        TriggerMoveAction(GetInitialMouseTargetPos, 0);
        NextState := lsAwaitInventory;
        Delay := cInitialSampleDelay;
      end;
    lsAwaitInventory:
      if DetectSampleBox then
      begin
        TriggerMoveAction(GetInitialMouseTargetPos, 0);
        if TriggerKeyAction(cLoadoutsKey) then
        begin
          NextState := lsAwaitLoadouts;
          Delay := cInitialLoadoutsDelay;
        end;
      end
      else if StateCount > cMaxSampleIterations then
        MessageBeep(MB_ICONERROR)
      else
      begin
        if Bool(StateCount mod 3) then
          TriggerKeyAction(cLoadoutsKey);

        NextState := lsAwaitInventory;
        Delay := cRepeatSampleDelay;
      end;
    lsAwaitLoadouts:
      if DetectLoadoutBar then
      begin
        TriggerMoveAction(coords.SlotCenter, 0);
        NextState := lsActivateLoadout;
        Delay := cInitialActivateDelay;
      end
      else if StateCount > cMaxLoadoutIterations then
        MessageBeep(MB_ICONERROR)
      else
      begin
        NextState := lsAwaitLoadouts;
        Delay := cRepeatLoadoutsDelay;
      end;
    lsActivateLoadout:
      if not DetectLoadoutBar then
      begin
        TriggerClickAction;
        NextState := lsExitInventory;
        Delay := cExitDelay;
      end
      else if StateCount > cMaxActivateIterations then
        MessageBeep(MB_ICONERROR)
      else
      begin
        TriggerMoveAction(coords.SlotCenter,
          (StateCount mod 3 - 1) * (coords.SlotDistance div 3));
        NextState := lsActivateLoadout;
        Delay := cRepeatActivateDelay;
      end;
    lsExitInventory:
      begin
        TriggerKeyAction(cInventoryKey);
      end;
  end;
end;

end.

unit StateMachine;

interface

uses
  ExtCtrls, Diagnostics;

type
  TTransitionProc<TState> = procedure(CurrentState: TState; StateCount: Integer;
    var NextState: TState; var Delay: Cardinal) of object;

  TCompletionProc = procedure(ElapsedMsec: Int64) of object;

  TStateMachine<TState> = class
  private
    transition: TTransitionProc<TState>;
    completed: TCompletionProc;
    stepper: TTimer;
    stopwatch: TStopwatch;
    currentState: TState;
    stateCount: Integer;

    procedure Step;
    procedure TimerProc(Sender: TObject);
  public
    constructor Create(Timer: TTimer; Proc: TCompletionProc);
    function IsIdle: Boolean;
    procedure Start(Proc: TTransitionProc<TState>);
  end;

implementation

uses
  SysUtils;

constructor TStateMachine<TState>.Create(Timer: TTimer; Proc: TCompletionProc);
begin
  stepper := Timer;
  stepper.OnTimer := TimerProc;
  completed := Proc;
end;

function TStateMachine<TState>.IsIdle: Boolean;
begin
  result := currentState = Default(TState);
end;

procedure TStateMachine<TState>.Start(Proc: TTransitionProc<TState>);
begin
  if IsIdle then
  begin
    stopWatch := TStopwatch.StartNew;
    transition := Proc;
    Step;
  end;
end;

procedure TStateMachine<TState>.Step;
var
  nextState: TState;
  delay: Cardinal;
begin
  delay := 0;
  nextState := Default(TState);
  try
    transition(currentState, stateCount, nextState, delay);
  except
    stepper.Enabled := false;
    currentState := Default(TState);
    raise;
  end;

  if currentState = nextState then
    Inc(stateCount)
  else
    stateCount := 0;

  currentState := nextState;

  if nextState <> Default(TState) then
  begin
    stepper.Interval := delay;
    stepper.Enabled := true;
  end
  else
  begin
    stepper.Enabled := false;
    stopwatch.Stop;
    completed(stopwatch.ElapsedMilliseconds);
  end;
end;

procedure TStateMachine<TState>.TimerProc(Sender: TObject);
begin
  Step;
end;

end.

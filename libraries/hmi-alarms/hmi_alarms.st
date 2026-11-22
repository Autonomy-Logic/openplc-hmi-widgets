(* One row of an alarm table. A row is Used while its alarm is active or unacknowledged. The HMI writes AckReq TRUE,
   with AckSeq, and HMI_ALARMS clears both. Severity: 1 low, 2 medium, 3 high. *)
TYPE HMI_ALARM_ROW :
  STRUCT
    Used : BOOL;
    Id : DINT;
    Severity : INT;
    Message : STRING(80);
    Active : BOOL;
    Acked : BOOL;
    Raised : DT;
    AckReq : BOOL;
    (* Occurrence number, set by HMI_ALARM on every raise to 1 + the highest Seq in the table; 0 before the first. *)
    Seq : UDINT;
    (* Written with AckReq: when not 0, the row is acknowledged only while Seq equals it; 0 acknowledges the row. *)
    AckSeq : UDINT;
    (* Changes of this scan, then of the last HMI_ALARMS call: 1 raised, 2 acknowledged, 4 cleared. *)
    Notify : BYTE;
    Pending : BYTE;
  END_STRUCT;
END_TYPE

(* What HMI_ALARMS reports about a table, and the acknowledgements the HMI asks of it: the HMI writes AckTop (with
   AckTopSeq) or AckAll TRUE and HMI_ALARMS clears them. Top is the newest unacknowledged alarm, else the newest active
   one. *)
TYPE HMI_ALARM_SUMMARY :
  STRUCT
    AckTop : BOOL;
    AckAll : BOOL;
    (* Written with AckTop: when not 0, acknowledges the Used row whose Seq equals it; 0 acknowledges the top. *)
    AckTopSeq : UDINT;
    Count : DINT;
    ActiveCount : DINT;
    Unacked : DINT;
    TopValid : BOOL;
    TopAcked : BOOL;
    TopId : DINT;
    TopSeverity : INT;
    TopMessage : STRING(80);
    TopRaised : DT;
    (* Row of the top alarm, for AckTop. *)
    TopRow : DINT;
    (* Seq of the top alarm, 0 when there is none. *)
    TopSeq : UDINT;
  END_STRUCT;
END_TYPE

(* One entry of an event log, a ring the writers fill in Seq order; Seq 0 is an empty entry. Kind: 1 alarm, 2
   acknowledged, 3 cleared, 4 event, 5 operator. *)
TYPE HMI_EVENT_ROW :
  STRUCT
    Seq : UDINT;
    Kind : INT;
    Severity : INT;
    Message : STRING(80);
    Stamp : DT;
  END_STRUCT;
END_TYPE

(* Appends an entry to the log after its newest one, overwriting the oldest when full. *)
FUNCTION HMI_LOG_EVENT : BOOL
  VAR_INPUT
    Message : STRING(80);
    Kind : INT := 4;
    Severity : INT := 0;
  END_VAR
  VAR_IN_OUT
    Events : ARRAY[*] OF HMI_EVENT_ROW;
  END_VAR
  VAR i, lo, hi, slot : DINT; newest : UDINT; END_VAR
  lo := LOWER_BOUND(Events, 1);
  hi := UPPER_BOUND(Events, 1);
  slot := lo;
  newest := 0;
  FOR i := lo TO hi DO
    IF Events[i].Seq > newest THEN
      newest := Events[i].Seq;
      slot := i + 1;
    END_IF;
  END_FOR;
  IF slot > hi THEN
    slot := lo;
  END_IF;
  Events[slot].Seq := newest + 1;
  Events[slot].Kind := Kind;
  Events[slot].Severity := Severity;
  Events[slot].Message := Message;
  Events[slot].Stamp := CURRENT_DT();
  HMI_LOG_EVENT := TRUE;
END_FUNCTION

(* One alarm, called every scan: while In is TRUE it holds a row of Table, found by Id (by Message when Id is 0), and
   raises it again when it was cleared, each raise with a new Seq. Returns FALSE when the table has no free row. *)
FUNCTION HMI_ALARM : BOOL
  VAR_INPUT
    In : BOOL;
    Id : DINT := 0;
    Severity : INT := 3;
    Message : STRING(80) := '';
  END_VAR
  VAR_IN_OUT
    Table : ARRAY[*] OF HMI_ALARM_ROW;
  END_VAR
  VAR
    row, i : DINT;
    has : BOOL;
    seq : UDINT;
  END_VAR
  HMI_ALARM := TRUE;
  FOR i := LOWER_BOUND(Table, 1) TO UPPER_BOUND(Table, 1) DO
    IF Table[i].Seq > seq THEN
      seq := Table[i].Seq;
    END_IF;
    IF NOT has AND Table[i].Used AND Table[i].Id = Id THEN
      IF Id <> 0 OR Table[i].Message = Message THEN
        row := i;
        has := TRUE;
      END_IF;
    END_IF;
  END_FOR;
  IF In THEN
    IF NOT has THEN
      FOR i := LOWER_BOUND(Table, 1) TO UPPER_BOUND(Table, 1) DO
        IF NOT has AND NOT Table[i].Used THEN
          row := i;
          has := TRUE;
          Table[i].Used := TRUE;
          Table[i].Id := Id;
          Table[i].Active := TRUE;
          Table[i].Acked := FALSE;
          Table[i].AckReq := FALSE;
          Table[i].AckSeq := 0;
          Table[i].Seq := seq + 1;
          Table[i].Raised := CURRENT_DT();
          Table[i].Notify := BYTE#1;
          Table[i].Pending := BYTE#0;
        END_IF;
      END_FOR;
      HMI_ALARM := has;
    ELSIF NOT Table[row].Active THEN
      Table[row].Active := TRUE;
      Table[row].Acked := FALSE;
      Table[row].Seq := seq + 1;
      Table[row].Raised := CURRENT_DT();
      Table[row].Notify := Table[row].Notify OR BYTE#1;
    END_IF;
    IF has THEN
      Table[row].Severity := Severity;
      Table[row].Message := Message;
    END_IF;
  ELSIF has THEN
    IF Table[row].Active THEN
      Table[row].Active := FALSE;
      Table[row].Notify := Table[row].Notify OR BYTE#4;
    END_IF;
  END_IF;
END_FUNCTION

(* The alarm table's service, called once per scan after the alarms: applies the acknowledgements the HMI asked for
   (AckReq of a row, Summary.AckTop, Summary.AckAll), each checked against its Seq when one is given, frees rows that
   are cleared and acknowledged, and fills Summary. *)
FUNCTION HMI_ALARMS : BOOL
  VAR_IN_OUT
    Summary : HMI_ALARM_SUMMARY;
    Table : ARRAY[*] OF HMI_ALARM_ROW;
  END_VAR
  VAR
    i, top : DINT;
    has, better, ack : BOOL;
  END_VAR
  FOR i := LOWER_BOUND(Table, 1) TO UPPER_BOUND(Table, 1) DO
    ack := Summary.AckAll;
    IF Table[i].AckReq THEN
      ack := ack OR Table[i].AckSeq = 0 OR Table[i].AckSeq = Table[i].Seq;
    END_IF;
    IF Summary.AckTop THEN
      IF Summary.AckTopSeq <> 0 THEN
        ack := ack OR Table[i].Seq = Summary.AckTopSeq;
      ELSE
        ack := ack OR (Summary.TopValid AND i = Summary.TopRow);
      END_IF;
    END_IF;
    IF Table[i].Used AND ack THEN
      IF NOT Table[i].Acked THEN
        Table[i].Acked := TRUE;
        Table[i].Notify := Table[i].Notify OR BYTE#2;
      END_IF;
    END_IF;
    Table[i].AckReq := FALSE;
    Table[i].AckSeq := 0;
    Table[i].Pending := Table[i].Notify;
    Table[i].Notify := BYTE#0;
    IF Table[i].Used AND NOT Table[i].Active AND Table[i].Acked THEN
      Table[i].Used := FALSE;
    END_IF;
  END_FOR;
  Summary.AckTop := FALSE;
  Summary.AckTopSeq := 0;
  Summary.AckAll := FALSE;
  Summary.Count := 0;
  Summary.ActiveCount := 0;
  Summary.Unacked := 0;
  FOR i := LOWER_BOUND(Table, 1) TO UPPER_BOUND(Table, 1) DO
    IF Table[i].Used THEN
      Summary.Count := Summary.Count + 1;
      IF Table[i].Active THEN
        Summary.ActiveCount := Summary.ActiveCount + 1;
      END_IF;
      IF NOT Table[i].Acked THEN
        Summary.Unacked := Summary.Unacked + 1;
      END_IF;
      IF NOT has THEN
        better := TRUE;
      ELSIF Table[i].Acked <> Table[top].Acked THEN
        better := NOT Table[i].Acked;
      ELSIF Table[i].Raised <> Table[top].Raised THEN
        better := Table[i].Raised > Table[top].Raised;
      ELSE
        better := Table[i].Severity > Table[top].Severity;
      END_IF;
      IF better THEN
        top := i;
        has := TRUE;
      END_IF;
    END_IF;
  END_FOR;
  Summary.TopValid := has;
  Summary.TopRow := top;
  IF has THEN
    Summary.TopAcked := Table[top].Acked;
    Summary.TopId := Table[top].Id;
    Summary.TopSeverity := Table[top].Severity;
    Summary.TopMessage := Table[top].Message;
    Summary.TopRaised := Table[top].Raised;
    Summary.TopSeq := Table[top].Seq;
  ELSE
    Summary.TopAcked := FALSE;
    Summary.TopId := 0;
    Summary.TopSeverity := 0;
    Summary.TopMessage := '';
    Summary.TopSeq := 0;
  END_IF;
  HMI_ALARMS := has;
END_FUNCTION

(* Logs what HMI_ALARMS saw change in Table: raised, acknowledged and cleared, in that order per row. Call it once per
   scan after HMI_ALARMS. Returns the number of entries written. *)
FUNCTION HMI_ALARM_LOGGER : DINT
  VAR_IN_OUT
    Table : ARRAY[*] OF HMI_ALARM_ROW;
    Events : ARRAY[*] OF HMI_EVENT_ROW;
  END_VAR
  VAR
    i : DINT;
    p : BYTE;
  END_VAR
  FOR i := LOWER_BOUND(Table, 1) TO UPPER_BOUND(Table, 1) DO
    p := Table[i].Pending;
    IF p <> BYTE#0 THEN
      IF (p AND BYTE#1) <> BYTE#0 THEN
        HMI_LOG_EVENT(Message := Table[i].Message, Kind := 1, Severity := Table[i].Severity, Events := Events);
        HMI_ALARM_LOGGER := HMI_ALARM_LOGGER + 1;
      END_IF;
      IF (p AND BYTE#2) <> BYTE#0 THEN
        HMI_LOG_EVENT(Message := Table[i].Message, Kind := 2, Severity := Table[i].Severity, Events := Events);
        HMI_ALARM_LOGGER := HMI_ALARM_LOGGER + 1;
      END_IF;
      IF (p AND BYTE#4) <> BYTE#0 THEN
        HMI_LOG_EVENT(Message := Table[i].Message, Kind := 3, Severity := Table[i].Severity, Events := Events);
        HMI_ALARM_LOGGER := HMI_ALARM_LOGGER + 1;
      END_IF;
      Table[i].Pending := BYTE#0;
    END_IF;
  END_FOR;
END_FUNCTION

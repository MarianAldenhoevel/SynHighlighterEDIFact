unit SynHighlighterEDIFact;

{$I SynEdit.inc}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  Generics.Collections,
  Vcl.Graphics,
  SynEditTypes,
  SynEditHighlighter,
  SynUnicode;

const
  DEF_COMPONENT_SEPARATOR = ':';  // Default component separator
  DEF_ELEMENT_SEPARATOR = '+';    // Default element separator
  DEF_DECIMAL_SEPARATOR = '.';    // Default decimal separator
  DEF_RELEASE_INDICATOR = '?';    // Default release indicator
  DEF_SPACE = ' ';                // Default space character
  DEF_SEGMENT_TERMINATOR = '''';  // Default segment terminator

  WhiteSpaceChars = [#0, #9, #10, #13, ' '];

  ValidSegmentTags: array of string = [
    'UNA',
    'UNB',
    'UNH',
    'UNT',
    'UNZ',
    'BGM',
    'DTM',
    'NAD',
    'LIN',
    'QTY',
    'UNS',
    'CNT',
    'RFF',
    'FTX',
    'DOC',
    'ERC'
  ];

type
  TTokenKind = (
    tkUnknown,
    tkSegmentTag,
    tkInvalidSegmentTag,
    tkComponentSeparator,
    tkElementSeparator,
    tkReleaseIndicator,
    tkSegmentTerminator,
    tkWhitespace,
    tkElementText
  );

type
  TSynEDIFactSyn = class(TSynCustomHighlighter)
  private
    FComponentSeparator: Char;
    FElementSeparator: Char;
    FDecimalSeparator: Char;
    FReleaseIndicator: Char;
    FSpace: Char;
    FSegmentTerminator: Char;

    FValidSegmentTags: TDictionary<string, boolean>;
    FCheckValidSegmentTags: boolean;

    FTokenKind: TTokenKind;

    FTokenAttributes: array[TTokenKind] of TSynHighlighterAttributes;

    function CreateHighlighterAttributes(Name: string; Foreground, Background: TColor; FontStyles: TFontStyles): TSynHighlighterAttributes;

    procedure UnknownProc;
    procedure SegmentTagProc;
    procedure ComponentSeparatorProc;
    procedure ElementSeparatorProc;
    procedure ReleaseIndicatorProc;
    procedure SegmentTerminatorProc;
    procedure ElementTextProc;
    procedure WhiteSpaceProc;

    procedure DefaultFormat;

    procedure SetCheckValidSegmentTags(aCheck: boolean);
  protected
    function GetSampleSource: UnicodeString; override;
    function IsFilterStored: Boolean; override;
    function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
  public
    class function GetLanguageName: string; override;
    class function GetFriendlyLanguageName: UnicodeString; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function GetTokenAttributes(aTokenKind: TTokenKind): TSynHighlighterAttributes;

    function GetEol: Boolean; override;
    function GetTokenID: TTokenKind;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: integer; override;

    procedure Next; override;

    procedure AddValidSegmentTag(aSegmentTag: string); overload;
    procedure AddValidSegmentTags(aSegmentTags: array of string);
  published
    property CheckValidSegmentTags: boolean read FCheckValidSegmentTags write SetCheckValidSegmentTags;
    // List of valid segment tags and attributes not published. Use code to configure them.
  end;

implementation

uses
  SynEditStrConst;

const
  FilterEDIFact = 'EDIFact Files (*.txt)|*.txt';

function TSynEDIFactSyn.CreateHighlighterAttributes(Name: string; Foreground, Background: TColor; FontStyles: TFontStyles): TSynHighlighterAttributes;
begin
  Result := TSynHighlighterAttributes.Create(Name, Name);
  if Foreground <> clNone then Result.Foreground := Foreground;
  if Background <> clNone then Result.Background := Background;
  Result.Style := FontStyles;

  AddAttribute(Result);
end;

constructor TSynEDIFactSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FValidSegmentTags := TDictionary<string, boolean>.Create();
  AddValidSegmentTags(ValidSegmentTags);
  FCheckValidSegmentTags := True;

  DefaultFormat();

  FCaseSensitive := true;

  FTokenAttributes[tkUnknown] :=            CreateHighlighterAttributes('Unknown',             clRed,   clNone, [fsItalic]);
  FTokenAttributes[tkSegmentTag] :=         CreateHighlighterAttributes('Segment Tag',         clNone,  clNone, [fsBold]);
  FTokenAttributes[tkInvalidSegmentTag] :=  CreateHighlighterAttributes('Invalid Segment Tag', clRed,   clNone, [fsBold]);
  FTokenAttributes[tkComponentSeparator] := CreateHighlighterAttributes('Component Separator', clRed,   clNone, []);
  FTokenAttributes[tkElementSeparator] :=   CreateHighlighterAttributes('Element Separator',   clBlue,  clNone, []);
  FTokenAttributes[tkReleaseIndicator] :=   CreateHighlighterAttributes('Release Indicator',   clGreen, clNone, []);
  FTokenAttributes[tkSegmentTerminator] :=  CreateHighlighterAttributes('Segment Terminator',  clRed,   clNone, [fsBold]);
  FTokenAttributes[tkWhiteSpace] :=         CreateHighlighterAttributes('Whitespace',          clNone,  clNone, []);
  FTokenAttributes[tkElementText] :=        CreateHighlighterAttributes('Element Text',        clNone,  clNone, []);

  SetAttributesOnChange(DefHighlightChange);

  fDefaultFilter := FilterEDIFact;
end;

destructor TSynEDIFactSyn.Destroy;
begin
  FreeAndNIL(FValidSegmentTags);
  inherited Destroy;
end;

procedure TSynEDIFactSyn.WhiteSpaceProc;
begin
  FTokenKind := tkWhiteSpace;
  inc(Run);
  while not GetEol() and CharInSet(FLine[Run], WhitespaceChars) do
    inc(Run);
end;

procedure TSynEDIFactSyn.ElementTextProc;
begin
  FTokenKind := tkElementText;
  inc(Run);
end;

procedure TSynEDIFactSyn.UnknownProc;
begin
  FTokenKind := tkUnknown;
  // Scan over the data until we guess a segment ends.
  inc(Run);
  while not CharInSet(FLine[Run], [#0, #13, #10, FSegmentTerminator]) do
    inc(Run);
end;

procedure TSynEDIFactSyn.SegmentTagProc;
var
  SegmentTag: string;
  UNASegment: string;
  i: Integer;
begin
  SegmentTag := copy(FLine, Run + 1, 3);
  if (Length(SegmentTag) < 3)
    then
      begin
        UnknownProc;
        exit;
      end
    else
      begin
        for i := 1 to Length(SegmentTag) do
          if (not CharInSet(SegmentTag[i], ['A'..'Z'])) then
            begin
              UnknownProc;
              exit;
            end;

        Run := Run + 3;

        // We have a syntactically valid segment tag. Is it valid?
        if FCheckValidSegmentTags and not FValidSegmentTags.ContainsKey(SegmentTag)
          then
            FTokenKind := tkInvalidSegmentTag
          else
            FTokenKind := tkSegmentTag;

        // If this is a UNA-Segment, then update the format characters.
        if (SegmentTag = 'UNA') then
          begin
            UNASegment := copy(FLine, Run - 3, 9);
            if Length(UNASegment) = 9 then
              begin
                FComponentSeparator :=  UNASegment[4];
                FElementSeparator :=    UNASegment[5];
                FDecimalSeparator :=    UNASegment[6];
                FReleaseIndicator :=    UNASegment[7];
                FSpace :=               UNASegment[8];
                FSegmentTerminator :=   UNASegment[9];
              end;
          end;
      end;
end;

procedure TSynEDIFactSyn.ComponentSeparatorProc;
begin
  FTokenKind := tkComponentSeparator;
  inc(Run);
end;

procedure TSynEDIFactSyn.ElementSeparatorProc;
begin
  FTokenKind := tkElementSeparator;
  inc(Run);
end;

procedure TSynEDIFactSyn.ReleaseIndicatorProc;
begin
  FTokenKind := tkReleaseIndicator;
  inc(Run);
end;

procedure TSynEDIFactSyn.SegmentTerminatorProc;
begin
  FTokenKind := tkSegmentTerminator;
  inc(Run);
end;

procedure TSynEDIFactSyn.Next;
begin
  FTokenPos := Run;

  if (Run = 0) or (FLine[Run - 1] = FSegmentTerminator)
    then SegmentTagProc
  else if (Run > 0) and (FLine[Run - 1] = FReleaseIndicator)
    then ElementTextProc
  else if FLine[Run] = FReleaseIndicator
    then ReleaseIndicatorProc
  else if FLine[Run] = FComponentSeparator
    then ComponentSeparatorProc
  else if FLine[Run] = FElementSeparator
    then ElementSeparatorProc
  else if FLine[Run] = FSegmentTerminator
    then SegmentTerminatorProc
  else if CharInSet(FLine[Run], WhitespaceChars)
    then WhiteSpaceProc
  else ElementTextProc;

  inherited;
end;

function TSynEDIFactSyn.GetDefaultAttribute(Index: integer): TSynHighlighterAttributes;
begin
  Result := NIL;
end;

function TSynEDIFactSyn.GetEol: Boolean;
begin
  Result := (Run > FLineLen);
end;

function TSynEDIFactSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  Result := FTokenAttributes[FTokenKind];
end;

function TSynEDIFactSyn.GetTokenID: TTokenKind;
begin
  Result := FTokenKind;
end;

function TSynEDIFactSyn.GetTokenKind: integer;
begin
  Result := Ord(GetTokenID);
end;

function TSynEDIFactSyn.IsFilterStored: Boolean;
begin
  Result := fDefaultFilter <> FilterEDIFact;
end;

class function TSynEDIFactSyn.GetLanguageName: string;
begin
  Result := 'EDIFact';
end;

class function TSynEDIFactSyn.GetFriendlyLanguageName: UnicodeString;
begin
  Result := GetLanguageName;
end;

function TSynEDIFactSyn.GetSampleSource: UnicodeString;
begin
  Result :=
    'UNA:+.? ''' + #13#10 +
    'UNB+UNOC:3+Sen??d?:e?+rkennung+Empfaengerkennung+060620:0931+1++1234567''' + #13#10 +
    'UNH+1+ORDERS:D:96A:UN''' + #13#10 +
    'BGM+220+B10001''' + #13#10 +
    'DTM+4:20060620:102''' + #13#10 +
    'NAD+BY+++Bestellername+Strasse+Stadt++23436+xx''' + #13#10 +
    'LIN+1++Produkt Schrauben:SA''' + #13#10 +
    'QTY+1:1000''' + #13#10 +
    'UNS+S''' + #13#10 +
    'CNT+2:1''' + #13#10 +
    'UNT+9+1''' + #13#10 +
    'UNZ+1+1234567''';
end;

function TSynEDIFactSyn.GetTokenAttributes(aTokenKind: TTokenKind): TSynHighlighterAttributes;
begin
  Result := FTokenAttributes[aTokenKind];
end;

procedure TSynEDIFactSyn.DefaultFormat;
begin
  FComponentSeparator := DEF_COMPONENT_SEPARATOR;
  FElementSeparator := DEF_ELEMENT_SEPARATOR;
  FDecimalSeparator := DEF_DECIMAL_SEPARATOR;
  FReleaseIndicator := DEF_RELEASE_INDICATOR;
  FSpace := DEF_SPACE;
  FSegmentTerminator := DEF_SEGMENT_TERMINATOR;
end;

procedure TSynEDIFactSyn.SetCheckValidSegmentTags(aCheck: boolean);
begin
  if aCheck <> FCheckValidSegmentTags then
    begin
      FCheckValidSegmentTags := aCheck;
      // TODO: Invalidate linked controls.
    end;
end;

procedure TSynEDIFactSyn.AddValidSegmentTag(aSegmentTag: string);
begin
  if not FValidSegmentTags.ContainsKey(aSegmentTag) then
    begin
      FValidSegmentTags.Add(aSegmentTag, true);
      // TODO: Invalidate linked controls.
    end;
end;

procedure TSynEDIFactSyn.AddValidSegmentTags(aSegmentTags: array of string);
var
  aSegmentTag: string;
begin
  BeginUpdate;
  try
    for aSegmentTag in aSegmentTags do
      AddValidSegmentTag(aSegmentTag);
  finally
    EndUpdate;
  end;
end;

{$IFNDEF SYN_CPPB_1}

initialization

RegisterPlaceableHighlighter(TSynEDIFactSyn);
{$ENDIF}

end.

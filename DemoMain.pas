unit DemoMain;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  SynEdit,
  SynMemo;

type
  TFrmDemoMain = class(TForm)
    smeEDIFactRaw: TSynMemo;
    smeEDIFactPretty: TSynMemo;
    Splitter1: TSplitter;

    procedure FormCreate(Sender: TObject);
  end;

var
  FrmDemoMain: TFrmDemoMain;

implementation

{$R *.dfm}

uses
  SynEditHighlighter,
  SynHighlighterEDIFact,
  SynHighlighterURI,
  SynHighlighterCSS,
  SynHighlighterTeX;

procedure TFrmDemoMain.FormCreate(Sender: TObject);
var
  Highlighter: TSynCustomHighlighter;
begin
  Highlighter := TSynEDIFactSyn.Create(Self);
  // Highlighter := TSynTeXSyn.Create(Self);


  smeEDIFactRaw.Text := StringReplace(Highlighter.SampleSource, #13#10, '', [rfReplaceAll]);
  smeEDIFactPretty.Text := Highlighter.SampleSource;

  smeEDIFactRaw.Highlighter := Highlighter;
  smeEDIFactPretty.Highlighter := Highlighter;
end;

end.

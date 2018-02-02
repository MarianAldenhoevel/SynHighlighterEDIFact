program Demo;

uses
  Vcl.Forms,
  DemoMain in 'DemoMain.pas' {FrmDemoMain},
  SynHighlighterEDIFact in 'SynHighlighterEDIFact.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmDemoMain, FrmDemoMain);
  Application.Run;
end.

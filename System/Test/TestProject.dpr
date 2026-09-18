// “естовый проект: TestProject.dpr
program TestProject;

{$APPTYPE CONSOLE}

uses
  TestFrameWork,
  TextTestRunner,
  TestSharedMem in 'TestSharedMem.pas';

begin
  // «апуск всех зарегистрированных тестов в консольном режиме
//  RunRegisteredTests;
//  TextTestRunner.RunRegisteredTests
//  RunTest(RegisteredTests);
  TextTestRunner.RunRegisteredTests;
end.

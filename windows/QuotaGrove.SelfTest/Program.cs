using QuotaGrove.Core;

var report = SelfTestRunner.Run();
if (report.Succeeded)
{
    Console.WriteLine($"PASS {report.Passed} 项");
    return 0;
}

Console.WriteLine($"FAIL {report.Failures.Count} 项；PASS {report.Passed} 项");
foreach (var failure in report.Failures) Console.WriteLine($"- {failure}");
return 1;

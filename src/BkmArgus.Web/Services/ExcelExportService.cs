using ClosedXML.Excel;

namespace BkmArgus.Web.Services;

public class ExcelExportService
{
    public byte[] Export<T>(IEnumerable<T> data, string sheetName, Dictionary<string, Func<T, object?>> columns)
    {
        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add(sheetName);

        // Header row
        var col = 1;
        foreach (var header in columns.Keys)
        {
            ws.Cell(1, col).Value = header;
            ws.Cell(1, col).Style.Font.Bold = true;
            ws.Cell(1, col).Style.Fill.BackgroundColor = XLColor.FromHtml("#2D2D2D");
            ws.Cell(1, col).Style.Font.FontColor = XLColor.White;
            col++;
        }

        // Data rows
        var row = 2;
        foreach (var item in data)
        {
            col = 1;
            foreach (var getter in columns.Values)
            {
                var value = getter(item);
                if (value is DateTime dt)
                    ws.Cell(row, col).Value = dt;
                else if (value is decimal d)
                    ws.Cell(row, col).Value = (double)d;
                else if (value is int i)
                    ws.Cell(row, col).Value = i;
                else if (value is bool b)
                    ws.Cell(row, col).Value = b ? "Evet" : "Hayir";
                else
                    ws.Cell(row, col).Value = value?.ToString() ?? "";
                col++;
            }
            row++;
        }

        ws.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }
}

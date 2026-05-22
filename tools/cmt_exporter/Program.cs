using System;
using System.IO;
using System.Runtime.Serialization.Formatters.Binary;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace FuGrade
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            try
            {
                if (args.Length < 2)
                {
                    Console.Error.WriteLine("Usage:\n  Export: FuGrade.exe <input.json> <output.cmt>\n  Import: FuGrade.exe <input.cmt> <output.json>");
                    return 1;
                }

                var inputPath = args[0];
                var outputPath = args[1];

                if (inputPath.EndsWith(".cmt", StringComparison.OrdinalIgnoreCase) || outputPath.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                {
                    // Import Mode: CMT to JSON
                    if (!File.Exists(inputPath))
                    {
                        Console.Error.WriteLine("Input CMT file does not exist.");
                        return 3;
                    }

                    var formatter = new BinaryFormatter();
                    ThesisComment comment;
                    using (var stream = File.OpenRead(inputPath))
                    {
                        comment = (ThesisComment)formatter.Deserialize(stream);
                    }

                    var dto = MapBack(comment);
                    var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
                    var json = serializer.Serialize(dto);
                    File.WriteAllText(outputPath, json, Encoding.UTF8);
                    return 0;
                }
                else
                {
                    // Export Mode: JSON to CMT
                    var json = File.ReadAllText(inputPath, Encoding.UTF8);
                    var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
                    var dto = serializer.Deserialize<ExportDto>(json);
                    if (dto == null)
                    {
                        Console.Error.WriteLine("Invalid JSON.");
                        return 2;
                    }

                    var comment = Map(dto);
                    if (string.IsNullOrWhiteSpace(comment.Password))
                    {
                        comment.Password = Md5Hex("1");
                    }

                    var formatter = new BinaryFormatter();
                    using (var stream = File.Create(outputPath))
                    {
                        formatter.Serialize(stream, comment);
                    }

                    return 0;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex);
                return 99;
            }
        }

        private static ThesisComment Map(ExportDto dto)
        {
            var students = new System.Collections.Generic.List<ThesisStudent>();
            if (dto.students != null)
            {
                foreach (var s in dto.students)
                {
                    students.Add(new ThesisStudent
                    {
                        Roll = s.roll ?? "",
                        Name = s.name ?? "",
                        Agree_to_defense = string.IsNullOrEmpty(s.agreeToDefense) ? "x" : s.agreeToDefense,
                        Revised_for_the_second_defense = s.revisedForSecondDefense ?? "",
                        Disagree_to_defense = s.disagreeToDefense ?? "",
                        Note = s.note ?? "",
                    });
                }
            }

            DateTime dtVal;
            return new ThesisComment
            {
                Teacher = dto.teacher ?? "",
                DT = DateTime.TryParse(dto.dt, out dtVal) ? dtVal : DateTime.Now,
                SubjectCode = dto.subjectCode ?? "",
                ClassName = dto.className ?? "",
                Semester = dto.semester ?? "",
                Password = dto.password ?? "",
                TitleVN = dto.titleVn ?? "",
                TitleEN = dto.titleEn ?? "",
                Content = dto.content ?? "",
                Form = dto.form ?? "",
                Attitude = dto.attitude ?? "",
                Achievement = dto.achievement ?? "",
                Limitation = dto.limitation ?? "",
                Conclusion = students,
            };
        }

        private static ExportDto MapBack(ThesisComment comment)
        {
            var students = new System.Collections.Generic.List<StudentDto>();
            if (comment.Conclusion != null)
            {
                foreach (var s in comment.Conclusion)
                {
                    students.Add(new StudentDto
                    {
                        roll = s.Roll ?? "",
                        name = s.Name ?? "",
                        agreeToDefense = s.Agree_to_defense ?? "",
                        revisedForSecondDefense = s.Revised_for_the_second_defense ?? "",
                        disagreeToDefense = s.Disagree_to_defense ?? "",
                        note = s.Note ?? "",
                    });
                }
            }

            return new ExportDto
            {
                teacher = comment.Teacher ?? "",
                dt = comment.DT.ToString("yyyy-MM-dd HH:mm:ss"),
                subjectCode = comment.SubjectCode ?? "",
                className = comment.ClassName ?? "",
                semester = comment.Semester ?? "",
                password = comment.Password ?? "",
                titleVn = comment.TitleVN ?? "",
                titleEn = comment.TitleEN ?? "",
                content = comment.Content ?? "",
                form = comment.Form ?? "",
                attitude = comment.Attitude ?? "",
                achievement = comment.Achievement ?? "",
                limitation = comment.Limitation ?? "",
                conclusion = "",
                students = students.ToArray(),
            };
        }

        private static string Md5Hex(string input)
        {
            using (var md5 = MD5.Create())
            {
                var bytes = md5.ComputeHash(Encoding.UTF8.GetBytes(input));
                var sb = new StringBuilder(bytes.Length * 2);
                foreach (var b in bytes)
                {
                    sb.Append(b.ToString("x2"));
                }
                return sb.ToString();
            }
        }
    }

    internal sealed class ExportDto
    {
        public string teacher { get; set; }
        public string dt { get; set; }
        public string subjectCode { get; set; }
        public string className { get; set; }
        public string semester { get; set; }
        public string password { get; set; }
        public string titleVn { get; set; }
        public string titleEn { get; set; }
        public string content { get; set; }
        public string form { get; set; }
        public string attitude { get; set; }
        public string achievement { get; set; }
        public string limitation { get; set; }
        public string conclusion { get; set; }
        public StudentDto[] students { get; set; }
    }

    internal sealed class StudentDto
    {
        public string roll { get; set; }
        public string name { get; set; }
        public string agreeToDefense { get; set; }
        public string revisedForSecondDefense { get; set; }
        public string disagreeToDefense { get; set; }
        public string note { get; set; }
    }
}

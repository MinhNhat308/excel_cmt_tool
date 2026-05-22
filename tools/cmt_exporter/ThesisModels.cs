using System;
using System.Collections.Generic;

namespace FuGrade
{
    [Serializable]
    public class ThesisComment
    {
        public ThesisComment()
        {
            Teacher = "";
            DT = DateTime.Now;
            SubjectCode = "";
            ClassName = "";
            Semester = "";
            Password = "";
            TitleVN = "";
            TitleEN = "";
            Content = "";
            Form = "";
            Attitude = "";
            Achievement = "";
            Limitation = "";
            Conclusion = new List<ThesisStudent>();
        }

        public string Teacher { get; set; }
        public DateTime DT { get; set; }
        public string SubjectCode { get; set; }
        public string ClassName { get; set; }
        public string Semester { get; set; }
        public string Password { get; set; }
        public string TitleVN { get; set; }
        public string TitleEN { get; set; }
        public string Content { get; set; }
        public string Form { get; set; }
        public string Attitude { get; set; }
        public string Achievement { get; set; }
        public string Limitation { get; set; }
        public List<ThesisStudent> Conclusion { get; set; }
    }

    [Serializable]
    public class ThesisStudent
    {
        public ThesisStudent()
        {
            Roll = "";
            Name = "";
            Agree_to_defense = "x";
            Revised_for_the_second_defense = "";
            Disagree_to_defense = "";
            Note = "";
        }

        public string Roll { get; set; }
        public string Name { get; set; }
        public string Agree_to_defense { get; set; }
        public string Revised_for_the_second_defense { get; set; }
        public string Disagree_to_defense { get; set; }
        public string Note { get; set; }
    }
}

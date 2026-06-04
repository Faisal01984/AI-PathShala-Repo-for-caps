import { createFileRoute, Navigate, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth-context";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Trash2, Loader2, BarChart3, Pencil } from "lucide-react";
import { toast } from "sonner";

export const Route = createFileRoute("/_app/admin")({ component: AdminPage });

type Lesson = { id: string; title: string; subject: string; grade: string; target_grade: string; teacher_id: string; teacher_name: string | null; created_at: string };
type Student = { id: string; full_name: string | null; email: string | null; assigned_grade: string | null; special_class: boolean; created_at: string };
type Teacher = { id: string; full_name: string | null; email: string | null; created_at: string; lesson_count: number };
type Submission = { id: string; file_name: string; lesson_id: string; lesson_title: string | null; student_id: string; student_name: string | null; created_at: string };

function AdminPage() {
  const { role, loading } = useAuth();
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [students, setStudents] = useState<Student[]>([]);
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [subs, setSubs] = useState<Submission[]>([]);
  const [busy, setBusy] = useState<string | null>(null);

  async function loadAll() {
    const [{ data: l }, { data: s }, { data: t }, { data: h }] = await Promise.all([
      supabase.rpc("principal_list_lessons" as any),
      supabase.rpc("principal_list_students" as any),
      supabase.rpc("principal_list_teachers" as any),
      supabase.rpc("principal_list_submissions" as any),
    ]);
    setLessons((l as Lesson[]) ?? []);
    setStudents((s as Student[]) ?? []);
    setTeachers((t as Teacher[]) ?? []);
    setSubs((h as Submission[]) ?? []);
  }

  useEffect(() => {
    if (role === "principal") loadAll();
  }, [role]);

  // Wait for the role to be resolved — otherwise principals briefly look like
  // students and get bounced back to /dashboard.
  if (loading || role === null) return <div className="text-muted-foreground">Loading…</div>;
  if (role !== "principal") return <Navigate to="/dashboard" />;

  async function deleteLesson(id: string) {
    if (!confirm("Delete this lesson permanently?")) return;
    setBusy(id);
    const { error } = await supabase.from("lessons").delete().eq("id", id);
    setBusy(null);
    if (error) return toast.error(error.message);
    toast.success("Lesson deleted");
    setLessons((x) => x.filter((l) => l.id !== id));
  }

  async function deleteSubmission(id: string) {
    if (!confirm("Delete this submission?")) return;
    setBusy(id);
    const { error } = await supabase.from("homework_submissions").delete().eq("id", id);
    setBusy(null);
    if (error) return toast.error(error.message);
    toast.success("Submission deleted");
    setSubs((x) => x.filter((s) => s.id !== id));
  }

  async function deleteStudent(id: string, name: string | null) {
    if (!confirm(`Permanently delete student "${name ?? id}" and all their data?`)) return;
    setBusy(id);
    const { error } = await supabase.rpc("principal_delete_student" as any, { _student_id: id });
    setBusy(null);
    if (error) return toast.error(error.message);
    toast.success("Student account deleted");
    setStudents((x) => x.filter((s) => s.id !== id));
    setSubs((x) => x.filter((s) => s.student_id !== id));
  }

  async function deleteTeacher(id: string, name: string | null) {
    if (!confirm(`Permanently delete teacher "${name ?? id}" and ALL their lessons, notifications, and integrations?`)) return;
    setBusy(id);
    const { error } = await supabase.rpc("principal_delete_teacher" as any, { _teacher_id: id });
    setBusy(null);
    if (error) return toast.error(error.message);
    toast.success("Teacher account deleted");
    setTeachers((x) => x.filter((t) => t.id !== id));
    setLessons((x) => x.filter((l) => l.teacher_id !== id));
  }

  return (
    <div className="space-y-8 max-w-6xl">
      <header className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className="font-display text-3xl font-bold">Principal admin</h1>
          <p className="text-muted-foreground text-sm">Manage all teachers, students, lessons, and submissions.</p>
        </div>
        <div className="flex gap-2">
          <Button asChild variant="outline" size="sm">
            <Link to="/progress"><BarChart3 className="h-3.5 w-3.5 mr-1" /> All students progress</Link>
          </Button>
          <Button asChild variant="outline" size="sm">
            <Link to="/library">Lesson library</Link>
          </Button>
        </div>
      </header>

      <Section title={`All teachers (${teachers.length})`}>
        {teachers.length === 0 ? <Empty /> : teachers.map((t) => (
          <Row key={t.id}
            primary={t.full_name ?? t.email ?? t.id}
            secondary={`${t.email ?? ""} · ${t.lesson_count} lesson${t.lesson_count === 1 ? "" : "s"}`}
            busy={busy === t.id}
            onDelete={() => deleteTeacher(t.id, t.full_name)}
            label="Delete account"
          />
        ))}
      </Section>

      <Section title={`All lessons (${lessons.length})`}>
        {lessons.length === 0 ? <Empty /> : lessons.map((l) => (
          <Card key={l.id} className="p-3 flex items-center justify-between gap-3">
            <div className="min-w-0">
              <div className="font-medium truncate">{l.title}</div>
              <div className="text-xs text-muted-foreground truncate">
                {l.subject} · Grade {l.grade} · Target: {l.target_grade} · Teacher: {l.teacher_name ?? "—"}
              </div>
            </div>
            <div className="flex gap-2 shrink-0">
              <Button asChild variant="outline" size="sm">
                <Link to="/lesson/$id" params={{ id: l.id }}><Pencil className="h-3.5 w-3.5 mr-1" /> View / Edit</Link>
              </Button>
              <Button variant="destructive" size="sm" onClick={() => deleteLesson(l.id)} disabled={busy === l.id}>
                {busy === l.id ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Trash2 className="h-3.5 w-3.5 mr-1" />}
                Delete
              </Button>
            </div>
          </Card>
        ))}
      </Section>

      <Section title={`All students (${students.length})`}>
        {students.length === 0 ? <Empty /> : students.map((s) => (
          <Row key={s.id}
            primary={s.full_name ?? s.email ?? s.id}
            secondary={`${s.email ?? ""} · Level: ${s.assigned_grade ?? "—"}${s.special_class ? " · AI Class" : ""}`}
            busy={busy === s.id}
            onDelete={() => deleteStudent(s.id, s.full_name)}
            label="Delete account"
          />
        ))}
      </Section>

      <Section title={`All homework submissions (${subs.length})`}>
        {subs.length === 0 ? <Empty /> : subs.map((s) => (
          <Row key={s.id}
            primary={s.file_name}
            secondary={`Lesson: ${s.lesson_title ?? s.lesson_id} · Student: ${s.student_name ?? s.student_id}`}
            busy={busy === s.id}
            onDelete={() => deleteSubmission(s.id)}
          />
        ))}
      </Section>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="font-display text-lg font-semibold mb-3">{title}</h2>
      <div className="space-y-2">{children}</div>
    </section>
  );
}

function Empty() {
  return <Card className="p-4 text-sm text-muted-foreground">Nothing here yet.</Card>;
}

function Row({ primary, secondary, onDelete, busy, label = "Delete" }: { primary: string; secondary: string; onDelete: () => void; busy: boolean; label?: string }) {
  return (
    <Card className="p-3 flex items-center justify-between gap-3">
      <div className="min-w-0">
        <div className="font-medium truncate">{primary}</div>
        <div className="text-xs text-muted-foreground truncate">{secondary}</div>
      </div>
      <Button variant="destructive" size="sm" onClick={onDelete} disabled={busy}>
        {busy ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Trash2 className="h-3.5 w-3.5 mr-1" />}
        {label}
      </Button>
    </Card>
  );
}

import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { supabaseAdmin } from "@/integrations/supabase/client.server";

const InputSchema = z.object({ lessonId: z.string().uuid() });

async function loadLessonAndEmails(lessonId: string, userId: string, supabase: any) {
  const { data: lesson, error: lessonErr } = await supabase
    .from("lessons")
    .select("id, teacher_id, target_grade, grade, title, subject")
    .eq("id", lessonId)
    .maybeSingle();
  if (lessonErr || !lesson) return { ok: false as const, error: "Lesson not found." };
  if (lesson.teacher_id !== userId) return { ok: false as const, error: "Not authorized." };

  const level = lesson.target_grade ?? lesson.grade;
  const { data: profiles, error: profErr } = await supabaseAdmin
    .from("profiles")
    .select("id, assigned_grade, special_class");
  if (profErr) return { ok: false as const, error: profErr.message };

  const matched = (profiles ?? []).filter((p: any) => {
    if (level === "All") return true;
    if (level === "AI Class") return p.special_class === true;
    return p.assigned_grade === level;
  });

  const emails: string[] = [];
  if (matched.length > 0) {
    const ids = matched.map((p: any) => p.id);
    const { data: roles } = await supabaseAdmin
      .from("user_roles")
      .select("user_id, role")
      .in("user_id", ids)
      .eq("role", "student");
    const studentIds = new Set((roles ?? []).map((r: any) => r.user_id));
    for (const id of ids) {
      if (!studentIds.has(id)) continue;
      const { data: u } = await supabaseAdmin.auth.admin.getUserById(id);
      const email = u?.user?.email;
      if (email) emails.push(email);
    }
  }
  return { ok: true as const, emails, lesson };
}

export const getLessonStudentEmails = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => InputSchema.parse(d))
  .handler(async ({ data, context }) => {
    const r = await loadLessonAndEmails(data.lessonId, context.userId, context.supabase);
    if (!r.ok) return r;
    return { ok: true as const, emails: r.emails, lessonTitle: r.lesson.title };
  });

export const generateLessonAnnouncement = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => InputSchema.parse(d))
  .handler(async ({ data, context }) => {
    const r = await loadLessonAndEmails(data.lessonId, context.userId, context.supabase);
    if (!r.ok) return r;
    const { emails, lesson } = r;

    const key = process.env.LOVABLE_API_KEY;
    let subject = `New lesson: ${lesson.title}`;
    let body =
      `Hi there!\n\nYour teacher has just shared a new lesson — "${lesson.title}". ` +
      `Jump in, explore the material, and come ready with your curiosity.\n\nHappy learning!`;

    if (key) {
      try {
        const res = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "google/gemini-3-flash-preview",
            messages: [
              {
                role: "system",
                content:
                  "You write short, warm, engaging announcement emails to students about a new lesson. Return STRICT JSON: {\"email_subject\": string, \"email_body\": string}. Keep subject under 70 chars. Keep body under 120 words, friendly tone, 1-2 short paragraphs, no markdown, no signature placeholder.",
              },
              {
                role: "user",
                content: `Write the announcement for the lesson titled "${lesson.title}"${lesson.subject ? ` (subject: ${lesson.subject})` : ""}.`,
              },
            ],
            response_format: { type: "json_object" },
          }),
        });
        if (res.ok) {
          const j = await res.json();
          const raw = j?.choices?.[0]?.message?.content ?? "{}";
          const parsed = JSON.parse(raw);
          if (parsed?.email_subject) subject = String(parsed.email_subject);
          if (parsed?.email_body) body = String(parsed.email_body);
        }
      } catch (e) {
        console.error("announcement gen failed", e);
      }
    }

    return {
      ok: true as const,
      emails,
      lessonTitle: lesson.title,
      emailSubject: subject,
      emailBody: body,
    };
  });

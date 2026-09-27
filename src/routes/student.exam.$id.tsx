import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useCallback, useEffect, useState } from "react";
import { WifiOff } from "lucide-react";
import { CbtExamPage } from "@/components/cbt/CbtExamSession";
import { Button } from "@/components/ui/button";
import { isOnlineNow } from "@/lib/offline-sync";

export const Route = createFileRoute("/student/exam/$id")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "CBT Examination — D4EXAM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ExamRouteGate,
});

/**
 * CBT exams require live timer sync, integrity checks, proctoring, and submission.
 * Block entry when offline; other student modules remain local-first.
 */
function ExamRouteGate() {
  const navigate = useNavigate();
  const [online, setOnline] = useState(() =>
    typeof navigator !== "undefined" ? isOnlineNow() : true,
  );

  useEffect(() => {
    const sync = () => setOnline(isOnlineNow());
    window.addEventListener("online", sync);
    window.addEventListener("offline", sync);
    sync();
    return () => {
      window.removeEventListener("online", sync);
      window.removeEventListener("offline", sync);
    };
  }, []);

  const retry = useCallback(() => {
    setOnline(isOnlineNow());
  }, []);

  if (!online) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-[#0b1b3a] px-4">
        <div className="w-full max-w-md rounded-2xl border border-slate-700/60 bg-[#0d1628] p-6 text-center shadow-xl">
          <div className="mx-auto mb-4 grid h-14 w-14 place-items-center rounded-2xl bg-amber-500/15 text-amber-400">
            <WifiOff className="h-7 w-7" />
          </div>
          <h1 className="text-lg font-bold text-slate-50">Internet Connection Required</h1>
          <p className="mt-3 text-sm leading-relaxed text-slate-400">
            A stable internet connection is required to verify security credentials, start
            proctoring, and submit your examination. Please reconnect to Wi-Fi or mobile data.
          </p>
          <div className="mt-6 flex flex-col gap-2 sm:flex-row sm:justify-center">
            <Button type="button" className="font-semibold" onClick={retry}>
              Retry Connection
            </Button>
            <Button
              type="button"
              variant="outline"
              className="border-slate-600 bg-transparent text-slate-200 hover:bg-slate-800"
              onClick={() => void navigate({ to: "/student" })}
            >
              Return to Dashboard
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return <CbtExamPage />;
}

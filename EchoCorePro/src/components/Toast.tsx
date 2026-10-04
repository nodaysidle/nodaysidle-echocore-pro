import React from "react";
import { AlertCircle, CheckCircle2, Info, X } from "lucide-react";
import { ToastMessage } from "../types";

interface ToastProps {
  toasts: ToastMessage[];
  onDismiss: (id: string) => void;
}

export const ToastContainer: React.FC<ToastProps> = ({ toasts, onDismiss }) => {
  if (toasts.length === 0) return null;

  return (
    <div className="fixed bottom-5 right-5 z-50 flex flex-col gap-2 pointer-events-none">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`pointer-events-auto flex items-start gap-3 p-3.5 rounded-xl border backdrop-blur-xl shadow-2xl animate-in slide-in-from-bottom-2 duration-200 max-w-sm ${
            toast.type === "success"
              ? "bg-emerald-950/80 border-emerald-500/30 text-emerald-200"
              : toast.type === "error"
              ? "bg-rose-950/80 border-rose-500/30 text-rose-200"
              : "bg-cyan-950/80 border-cyan-500/30 text-cyan-200"
          }`}
        >
          {toast.type === "success" && <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />}
          {toast.type === "error" && <AlertCircle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />}
          {toast.type === "info" && <Info className="w-4 h-4 text-cyan-400 shrink-0 mt-0.5" />}

          <div className="min-w-0 flex-1">
            <h4 className="text-xs font-semibold leading-tight">{toast.title}</h4>
            {toast.message && <p className="text-[11px] opacity-80 mt-0.5 leading-snug">{toast.message}</p>}
          </div>

          <button
            onClick={() => onDismiss(toast.id)}
            className="p-1 opacity-70 hover:opacity-100 transition-opacity cursor-pointer shrink-0"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      ))}
    </div>
  );
};

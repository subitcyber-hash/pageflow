import Sidebar from "@/components/Sidebar";
import MobileNav from "@/components/MobileNav";
import MobileHeader from "@/components/MobileHeader";
import PWAInstallPrompt from "@/components/PWAInstallPrompt";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[#0a0a0f]">
      <div className="hidden md:block">
        <Sidebar />
      </div>
      <MobileHeader />
      <main className="min-h-screen md:ml-60 pt-[calc(56px+env(safe-area-inset-top))] pb-[calc(72px+env(safe-area-inset-bottom))] md:pt-0 md:pb-0">
        {children}
      </main>
      <MobileNav />
      <PWAInstallPrompt />
    </div>
  );
}
import { CalendarDays, Grid2X2, Home, UserRound } from "lucide-react";

export type PrimaryRoute = "home" | "calendar" | "categories" | "profile";

const destinations = [
  { id: "home", label: "首页", Icon: Home },
  { id: "calendar", label: "日历", Icon: CalendarDays },
  { id: "categories", label: "分类", Icon: Grid2X2 },
  { id: "profile", label: "我的", Icon: UserRound }
] as const;

interface BottomNavigationProps {
  route: PrimaryRoute;
  onNavigate: (route: PrimaryRoute) => void;
}

export function BottomNavigation({ route, onNavigate }: BottomNavigationProps) {
  return (
    <nav className="bottom-nav" aria-label="主导航">
      {destinations.map(({ id, label, Icon }) => (
        <button
          className={route === id ? "nav-button is-selected" : "nav-button"}
          key={id}
          type="button"
          aria-label={label}
          aria-current={route === id ? "page" : undefined}
          onClick={() => onNavigate(id)}
        >
          <Icon aria-hidden="true" strokeWidth={2} />
        </button>
      ))}
    </nav>
  );
}

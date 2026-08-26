interface Props {
  className?: string;
  color?: string;
  strokeWidth?: number;
}

export const EcgLine = ({ className = "", color = "currentColor", strokeWidth = 2 }: Props) => (
  <svg
    className={className}
    viewBox="0 0 1200 120"
    preserveAspectRatio="none"
    aria-hidden="true"
  >
    <path
      className="ecg-path"
      d="M0,60 L180,60 L200,60 L210,40 L220,80 L235,20 L250,100 L265,60 L420,60 L440,60 L450,40 L460,80 L475,20 L490,100 L505,60 L660,60 L680,60 L690,40 L700,80 L715,20 L730,100 L745,60 L900,60 L920,60 L930,40 L940,80 L955,20 L970,100 L985,60 L1200,60"
      fill="none"
      stroke={color}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
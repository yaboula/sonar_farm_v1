import { CaretDown, Check } from "@phosphor-icons/react";
import {
  type KeyboardEvent,
  useEffect,
  useId,
  useRef,
  useState,
} from "react";

export interface FarmSelectOption<T extends string = string> {
  value: T;
  label: string;
  description?: string;
  disabled?: boolean;
}

interface FarmSelectProps<T extends string> {
  label: string;
  value: T;
  options: readonly FarmSelectOption<T>[];
  onChange: (value: T) => void;
  autoFocus?: boolean;
  className?: string;
  disabled?: boolean;
  size?: "default" | "compact";
}

export function FarmSelect<T extends string>({
  label,
  value,
  options,
  onChange,
  autoFocus = false,
  className = "",
  disabled = false,
  size = "default",
}: FarmSelectProps<T>) {
  const generatedId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const selectedIndex = Math.max(options.findIndex((option) => option.value === value), 0);
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(selectedIndex);

  const labelId = `${generatedId}-label`;
  const listboxId = `${generatedId}-listbox`;

  useEffect(() => {
    if (autoFocus) triggerRef.current?.focus();
  }, [autoFocus]);

  useEffect(() => {
    if (!open) return;
    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", closeOnOutsidePointer);
    return () => document.removeEventListener("pointerdown", closeOnOutsidePointer);
  }, [open]);

  const findEnabledIndex = (start: number, direction: 1 | -1) => {
    if (!options.length) return -1;
    let index = start;
    for (let attempts = 0; attempts < options.length; attempts += 1) {
      index = (index + direction + options.length) % options.length;
      if (!options[index]?.disabled) return index;
    }
    return start;
  };

  const selectIndex = (index: number) => {
    const option = options[index];
    if (!option || option.disabled) return;
    onChange(option.value);
    setOpen(false);
    triggerRef.current?.focus();
  };

  const openMenu = () => {
    if (disabled || !options.length) return;
    setActiveIndex(selectedIndex);
    setOpen(true);
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (disabled) return;

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const direction = event.key === "ArrowDown" ? 1 : -1;
      if (!open) {
        openMenu();
        setActiveIndex(findEnabledIndex(selectedIndex - direction, direction));
      } else {
        setActiveIndex((index) => findEnabledIndex(index, direction));
      }
      return;
    }

    if (event.key === "Home" || event.key === "End") {
      event.preventDefault();
      openMenu();
      const start = event.key === "Home" ? options.length - 1 : 0;
      const direction = event.key === "Home" ? 1 : -1;
      setActiveIndex(findEnabledIndex(start, direction));
      return;
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      if (open) selectIndex(activeIndex);
      else openMenu();
      return;
    }

    if (event.key === "Escape" && open) {
      event.preventDefault();
      event.stopPropagation();
      setOpen(false);
      return;
    }

    if (event.key === "Tab") setOpen(false);
  };

  const selected = options[selectedIndex];

  return (
    <div
      ref={rootRef}
      className={`farm-select farm-select--${size} ${open ? "is-open" : ""} ${className}`.trim()}
    >
      <span className="farm-select-label" id={labelId}>{label}</span>
      <button
        ref={triggerRef}
        type="button"
        className="farm-select-trigger"
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listboxId}
        aria-labelledby={labelId}
        aria-activedescendant={open && activeIndex >= 0 ? `${generatedId}-option-${activeIndex}` : undefined}
        disabled={disabled}
        onClick={() => (open ? setOpen(false) : openMenu())}
        onKeyDown={handleKeyDown}
      >
        <span>{selected?.label ?? "Select"}</span>
        <CaretDown size={17} weight="bold" aria-hidden="true" />
      </button>

      {open ? (
        <div className="farm-select-menu" id={listboxId} role="listbox" aria-labelledby={labelId}>
          {options.map((option, index) => {
            const isSelected = option.value === value;
            const isActive = index === activeIndex;
            return (
              <button
                key={option.value}
                id={`${generatedId}-option-${index}`}
                type="button"
                role="option"
                aria-selected={isSelected}
                aria-disabled={option.disabled || undefined}
                tabIndex={-1}
                className={`${isSelected ? "is-selected" : ""} ${isActive ? "is-active" : ""}`.trim()}
                onMouseEnter={() => !option.disabled && setActiveIndex(index)}
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => selectIndex(index)}
              >
                <span className="farm-select-option-copy">
                  <strong>{option.label}</strong>
                  {option.description ? <small>{option.description}</small> : null}
                </span>
                <Check className="farm-select-check" size={16} weight="bold" aria-hidden="true" />
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

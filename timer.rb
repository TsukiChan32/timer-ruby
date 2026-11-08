#!/usr/bin/env ruby
require "io/console"

def parse_duration(str)
  return str.to_i if str.match?(/\A\d+\z/)

  h = str[/(\d+)h/, 1].to_i
  m = str[/(\d+)m/, 1].to_i
  s = str[/(\d+)s/, 1].to_i
  h * 3600 + m * 60 + s
end

def fmt(sec)
  format("%02d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60)
end

GLYPHS = {
  "0" => ["█████", "█   █", "█   █", "█   █", "█████"],
  "1" => ["  █  ", " ██  ", "  █  ", "  █  ", " ███ "],
  "2" => ["█████", "    █", "█████", "█    ", "█████"],
  "3" => ["█████", "    █", "█████", "    █", "█████"],
  "4" => ["█   █", "█   █", "█████", "    █", "    █"],
  "5" => ["█████", "█    ", "█████", "    █", "█████"],
  "6" => ["█████", "█    ", "█████", "█   █", "█████"],
  "7" => ["█████", "    █", "    █", "    █", "    █"],
  "8" => ["█████", "█   █", "█████", "█   █", "█████"],
  "9" => ["█████", "█   █", "█████", "    █", "█████"],
  ":" => ["   ", " █ ", "   ", " █ ", "   "]
}.freeze

# Zamienia "01:23:45" na 5 wierszy dużych cyfr
def big_text(text)
  (0...5).map { |row| text.chars.map { |c| GLYPHS[c][row] }.join(" ") }
end

def render(remaining, total, paused, done)
  rows, cols = IO.console.winsize
  bar_w = [[cols - 12, 50].min, 10].max
  ratio = 1 - remaining / total
  filled = (ratio * bar_w).round
  bar = "█" * filled + "░" * (bar_w - filled)

  status = if done then "KONIEC!"
           elsif paused then "PAUZA"
           else "odliczanie..."
           end

  lines = big_text(fmt(remaining.ceil)) + [
    "",
    "[#{bar}] #{(ratio * 100).floor}%",
    status,
    "",
    "spacja: pauza   r: reset   q: wyjście"
  ]

  out = +"\e[H\e[J" # kursor na górę + wyczyść ekran
  lines.each_with_index do |line, i|
    row = [rows / 2 - lines.size / 2, 1].max + i
    col = [(cols - line.length) / 2, 0].max + 1
    out << "\e[#{row};#{col}H#{line}"
  end
  print out
  $stdout.flush
end

total = parse_duration(ARGV[0] || "25m")
abort "Użycie: ruby timer.rb [25m | 1h30m | 90s | 300]" if total <= 0

now = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
remaining = total.to_f
paused = false
done = false
last = now.call

print "\e[?1049h\e[?25l" # osobny ekran + ukryj kursor
begin
  $stdin.raw do |io|
    loop do
      t = now.call
      remaining -= t - last unless paused || done
      last = t

      if remaining <= 0 && !done
        remaining = 0.0
        done = true
        print "\a" # sygnał dźwiękowy
      end

      render(remaining, total, paused, done)

      next unless IO.select([io], nil, nil, 0.1)

      case io.getch
      when " " then paused = !paused unless done
      when "r" then remaining = total.to_f; done = false; paused = false
      when "q", "\u0003" then break # q lub Ctrl+C
      end
    end
  end
ensure
  print "\e[?25h\e[?1049l" # przywróć kursor i ekran
end

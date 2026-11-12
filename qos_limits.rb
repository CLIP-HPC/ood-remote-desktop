# Limits of the interactive QOS that every OOD session gets on CBE.next, whatever the
# partition. Read from Slurm, so the form follows QOS changes. Loaded by form.yml.erb and
# submit.yml.erb, which run as the user on the OOD host.
require "open3"

module RemoteDesktopQos
  # Used when sacctmgr or squeue fails, and for a limit the QOS doesn't set (2026-11 values)
  # (guarded: the ERB files `load` this file on every render)
  FALLBACK = { hours: 12, cpu: 48, mem_gb: 1000, gpu: 2, jobs: 5 }.freeze unless const_defined?(:FALLBACK)

  # Per-session wall time and per-user totals of the interactive QOS
  def self.limits
    out, status = Open3.capture2("sacctmgr", "-nP", "show", "qos", "interactive",
                                 "format=maxwall,maxtrespu,maxjobspu")
    line = out.lines.first
    return FALLBACK unless status.success? && line

    wall, tres, jobs = line.strip.split("|", -1)
    tres = tres.to_s.split(",").to_h { |kv| kv.split("=", 2) }
    {
      hours: wall_hours(wall) || FALLBACK[:hours],
      cpu: tres["cpu"]&.to_i || FALLBACK[:cpu],
      mem_gb: mem_gb(tres["mem"]) || FALLBACK[:mem_gb],
      gpu: tres["gres/gpu"]&.to_i || FALLBACK[:gpu],
      jobs: jobs.to_s.empty? ? FALLBACK[:jobs] : jobs.to_i
    }
  rescue StandardError
    FALLBACK
  end

  # What the user's running and pending interactive sessions already use
  def self.usage
    out, status = Open3.capture2("squeue", "--me", "-h", "-q", "interactive", "-t", "PD,R",
                                 "-O", "NumCPUs:|,MinMemory:|,tres-per-node:")
    return { jobs: 0, cpu: 0, mem_gb: 0, gpu: 0 } unless status.success?

    out.lines.each_with_object({ jobs: 0, cpu: 0, mem_gb: 0, gpu: 0 }) do |line, sum|
      cpu, mem, gres = line.split("|").map(&:strip)
      sum[:jobs] += 1
      sum[:cpu] += cpu.to_i
      sum[:mem_gb] += mem_gb(mem).to_i
      sum[:gpu] += gres.to_s[/gpu(?::[^:,]+)?:(\d+)/, 1].to_i
    end
  rescue StandardError
    { jobs: 0, cpu: 0, mem_gb: 0, gpu: 0 }
  end

  # "12:00:00", "2-00:00:00" -> whole hours
  def self.wall_hours(wall)
    m = wall.to_s.match(/\A(?:(\d+)-)?(\d+):(\d+):(\d+)\z/) or return nil
    m[1].to_i * 24 + m[2].to_i
  end

  # "1000G", "1T", "512000M" -> GB
  def self.mem_gb(mem)
    m = mem.to_s.match(/\A(\d+(?:\.\d+)?)([KMGT]?)\z/) or return nil
    (m[1].to_f * { "K" => 1.0 / 1024**2, "M" => 1.0 / 1024, "" => 1.0 / 1024, "G" => 1, "T" => 1024 }[m[2]]).floor
  end
end

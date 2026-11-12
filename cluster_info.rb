# Partitions and GPU types of the cluster the form runs on, read from Slurm, so the form
# follows the cluster (orion has only c, atlas has c, g and m) without code changes.
# Loaded by form.yml.erb and submit.yml.erb, which run as the user on the OOD host.
require "open3"

module RemoteDesktopCluster
  # (guarded: the ERB files `load` this file on every render)
  unless const_defined?(:PARTITIONS)
    # Partitions a desktop may use, in form order. Others (if any) aren't offered.
    PARTITIONS = {
      "c" => "CPU (c)",
      "g" => "GPU (g)",
      "m" => "High memory (m)"
    }.freeze

    # Friendly labels for known Slurm GRES types; a new type shows its plain name.
    # MIG slices are CUDA-only.
    GPU_LABELS = {
      "nvidia_b200_1g.23gb" => "B200 MIG slice, 23 GB",
      "nvidia_a100_3g.20gb" => "A100 MIG slice, 20 GB",
      "quadro_rtx_6000" => "Quadro RTX 6000, 24 GB",
      "nvidia_a100-sxm4-40gb" => "A100, 40 GB",
      "nvidia_b200" => "B200, 180 GB"
    }.freeze

    # Used when sinfo fails or shows nothing: the 2026-11 atlas values,
    # GPU type => most GPUs of that type on one node
    FALLBACK_PARTITIONS = PARTITIONS.keys.freeze
    FALLBACK_GPUS = {
      "nvidia_b200_1g.23gb" => 56,
      "nvidia_a100_3g.20gb" => 8,
      "quadro_rtx_6000" => 4,
      "nvidia_a100-sxm4-40gb" => 4,
      "nvidia_b200" => 8
    }.freeze
  end

  # Known partitions that exist on this cluster, in PARTITIONS order
  def self.partitions
    out, status = Open3.capture2("sinfo", "-h", "-o", "%P")
    return FALLBACK_PARTITIONS unless status.success?

    found = out.split.map { |p| p.delete_suffix("*") }
    list = PARTITIONS.keys & found
    list.empty? ? FALLBACK_PARTITIONS : list
  rescue StandardError
    FALLBACK_PARTITIONS
  end

  # GPU types on partition g => most GPUs of that type on one node.
  # Empty if the cluster has no partition g.
  def self.gpus(partitions = self.partitions)
    return {} unless partitions.include?("g")

    out, status = Open3.capture2("sinfo", "-p", "g", "-h", "-o", "%G")
    return FALLBACK_GPUS unless status.success?

    # Lines like "gpu:nvidia_b200:8(S:0-7)", possibly several GRES per line
    found = out.scan(/gpu:([^:,()\s]+):(\d+)/).each_with_object({}) do |(type, count), max|
      max[type] = [max[type].to_i, count.to_i].max
    end
    found.empty? ? FALLBACK_GPUS : sort_gpus(found)
  rescue StandardError
    FALLBACK_GPUS
  end

  # Known types in GPU_LABELS order, then new ones by name
  def self.sort_gpus(gpus)
    known = GPU_LABELS.keys
    gpus.sort_by { |type, _| [known.index(type) || known.size, type] }.to_h
  end

  def self.gpu_label(type)
    GPU_LABELS.fetch(type, type)
  end
end

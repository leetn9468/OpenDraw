#!/bin/sh
set -eu

workflow=${1:-.github/workflows/ci.yml}
injected_extra=${BENCHMARK_PRODUCTION_ENV_EXTRA_OFF:-}

ruby -ryaml -e '
  workflow, injected_extra = ARGV
  document = YAML.safe_load(File.read(workflow), aliases: true)
  steps = document.fetch("jobs").fetch("benchmark").fetch("steps")
  matches = steps.select { |step| step["name"] == "Run benchmark with frozen absolute targets" }
  abort("production benchmark step count=#{matches.length}, expected=1") unless matches.length == 1

  actual = (matches.first["env"] || {}).to_h.transform_keys(&:to_s).transform_values(&:to_s)
  actual[injected_extra] = "off" unless injected_extra.empty?
  expected = {
    "BENCH5B_ENFORCEMENT" => "off",
    "BENCH6_TIMING_ENFORCEMENT" => "off",
  }
  describe = ->(values) { values.sort.map { |key, value| "#{key}=#{value}" }.join(",") }

  unless actual == expected
    warn(
      "production_benchmark_timing_env_exactness=FAIL " \
      "expected=#{describe.call(expected)} actual=#{describe.call(actual)}"
    )
    exit 1
  end
  puts(
    "production_benchmark_timing_env=#{describe.call(actual)} " \
    "result=PASS"
  )
' "$workflow" "$injected_extra"

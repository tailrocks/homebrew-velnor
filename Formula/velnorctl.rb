class Velnorctl < Formula
  desc "Native operator CLI for Velnor"
  homepage "https://github.com/tailrocks/velnor"
  url "https://github.com/tailrocks/velnor/archive/refs/tags/v0.1.274.tar.gz"
  sha256 "106c7c439e5a57137b48c7fe20c7fe5ccc7aabb321a2e604cbde2b59a95301a6"
  license "Apache-2.0"

  depends_on "rust" => :build

  def install
    ENV["CARGO_REGISTRIES_CRATES_IO_PROTOCOL"] = "sparse"
    ENV["CARGO_NET_GIT_FETCH_WITH_CLI"] = "true"
    system "cargo", "install", *std_cargo_args(path: "crates/velnorctl")
    system "cargo", "install", *std_cargo_args(path: "crates/velnor-runner")

    (var/"velnor").mkpath
    (var/"log").mkpath
  end

  service do
    name macos: "com.tailrocks.velnor"
    run [opt_bin/"velnor-runner", "daemon"]
    keep_alive true
    environment_variables PATH: std_service_path_env
    process_type :standard
    working_dir var/"velnor"
    log_path var/"log/velnor.log"
    error_log_path var/"log/velnor.log"
    stop_timeout 10800
  end

  test do
    assert_match "Velnor operator CLI", shell_output("#{bin}/velnorctl --help")
    assert_match(/\A\d+\.\d+\.\d+\n\z/, shell_output("#{bin}/velnorctl version"))
    assert_match "Velnor daemon service entrypoint", shell_output("#{bin}/velnor-runner --help")
  end
end

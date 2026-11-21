def package_name: split("/")[0];
def package_version: split("/")[1];
def watched: test("^(microsoft\\.extensions|microsoft\\.aspnetcore)\\."; "i");
def major: package_version | split(".")[0] | tonumber;
def first_direct($reverse; $direct; $start):
  def walk($frontier; $seen):
    if ($frontier | length) == 0 then null
    else
      ([$frontier[] | select(. as $n | $direct | index($n | ascii_downcase))]) as $hits
      | if ($hits | length) > 0 then $hits[0]
        else
          ([$frontier[] | ($reverse[ascii_downcase] // [])[]] | unique - $seen) as $next
          | walk($next; $seen + $next)
        end
    end;
  walk([$start]; [$start]);
. as $assets
| ($assets.targets // {}) | to_entries[]
| select(.key | test("^net10\\.0(-[^/]+)?(/.*)?$"; "i"))
| .key as $target
| .value as $libraries
| ([($assets.projectFileDependencyGroups[$target | split("/")[0]] // [])[] | split(" ")[0] | ascii_downcase]) as $direct
| (reduce ($libraries | to_entries[]) as $library ({};
    reduce (($library.value.dependencies // {}) | keys[]) as $dependency (.;
      .[$dependency | ascii_downcase] += [$library.key | package_name]))) as $reverse
| $libraries | to_entries[]
| select(.value.type == "package")
| select(.key | package_name | watched)
| select(.key | major >= 11)
| (.key | package_name) as $package
| (.key | package_version) as $version
| (.key | major) as $major
| select(($allowed | index(($package | ascii_downcase) + "@" + ($major | tostring))) | not)
| first_direct($reverse; $direct; $package) as $top
| if $top == null then "\($package) \($version) (via a project reference)"
  elif ($top | ascii_downcase) == ($package | ascii_downcase) then "\($package) \($version) (direct dependency)"
  else "\($package) \($version) (via \($top))"
  end

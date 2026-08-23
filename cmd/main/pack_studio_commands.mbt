///|
fn pack_authority(value : String) -> @pack.AuthorityClass raise {
  match value.trim() {
    "Observe" => Observe
    "CognitiveMaintenance" => CognitiveMaintenance
    "SandboxExecution" => SandboxExecution
    "WorkspaceMutation" => WorkspaceMutation
    "ExternalEffect" => ExternalEffect
    "PhysicalEffect" => PhysicalEffect
    _ => fail("unknown authority `\{value}`")
  }
}

///|
fn pack_authorities(value : String) -> Array[@pack.AuthorityClass] raise {
  let authorities : Array[@pack.AuthorityClass] = []
  if !value.trim().is_empty() {
    for item in value.split(",") {
      authorities.push(pack_authority(item.to_owned()))
    }
  }
  authorities
}

///|
fn pack_extensions(value : String) -> Array[String] {
  let extensions : Array[String] = []
  if !value.trim().is_empty() {
    for item in value.split(",") {
      let item = item.to_owned().trim().to_owned()
      if !item.is_empty() {
        extensions.push(item)
      }
    }
  }
  extensions
}

///|
fn print_pack_studio_usage() -> Unit {
  println(
    "MoonDesk Pack Studio\n" +
    "  pack inspect <workspace> <source>\n" +
    "  pack create <workspace> <parent> <pack-id> <display-name> <product-id> <intake-operation> <output-schema>\n" +
    "  pack adopt-bridge <workspace> <source> <intake-operation> <output-schema>\n" +
    "  pack install <workspace> <source> <authorities-csv> <runtime-extensions-csv>\n" +
    "  pack activate <workspace> <pack-id> <version>\n" +
    "  pack deactivate <workspace> <pack-id>\n" +
    "  pack catalog <workspace>",
  )
}

///|
async fn run_pack_studio(args : Array[String]) -> Unit {
  let result = try {
    match args {
      ["inspect", workspace, source] =>
        @packstudio.inspect_pack_source(source, workspace).to_json()
      [
        "create",
        workspace,
        parent,
        pack_id,
        display_name,
        product_id,
        intake_operation_id,
        output_schema_id,
      ] =>
        @packstudio.create_domain_pack_scaffold(
          {
            parent_root: parent,
            pack_id,
            display_name,
            product_id,
            intake_operation_id,
            output_schema_id,
          },
          workspace,
        ).to_json()
      ["adopt-bridge", workspace, source, intake_operation_id, output_schema_id] =>
        @packstudio.adopt_pack_bridge(
          { source_root: source, intake_operation_id, output_schema_id },
          workspace,
        ).to_json()
      ["install", workspace, source, authorities, extensions] =>
        @packstudio.install_pack_source(
          {
            source_root: source,
            granted_authorities: pack_authorities(authorities),
            runtime_extensions: pack_extensions(extensions),
          },
          workspace,
        ).to_json()
      ["activate", workspace, pack_id, version] =>
        @packstudio.activate_pack_version({ pack_id, version }, workspace).to_json()
      ["deactivate", workspace, pack_id] => {
        let deactivated = @packstudio.deactivate_pack({ pack_id, }, workspace)
        { "pack_id": pack_id, "deactivated": deactivated }
      }
      ["catalog", workspace] => @packstudio.active_pack_catalog(workspace)
      _ => {
        print_pack_studio_usage()
        return
      }
    }
  } catch {
    error => {
      let payload : Json = { "ok": false, "error": "\{error}" }
      println(payload.stringify(indent=2))
      return
    }
  }
  println(result.stringify(indent=2))
}

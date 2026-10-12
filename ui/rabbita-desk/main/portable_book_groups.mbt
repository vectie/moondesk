///|
struct PortableBookGroupFile {
  source_path : String
  path : String
} derive(Eq, Debug, ToJson)

///|
struct PortableBookGroup {
  artifact_id : String
  label : String
  root : String
  files : Array[PortableBookGroupFile]
  preview_path : String?
  app_entrypoint : String?
} derive(Eq, Debug)

///|
enum PortableGroupMsg {
  NameNewGroup(String)
  AddGroup
  SelectGroup(String)
  RenameGroup(String, String)
  RemoveGroup(String)
  ToggleGroupFile(String)
  RemoveGroupFile(String, String)
  ChooseGroupPreview(String, String)
  ChooseGroupEntrypoint(String, String)
}

///|
fn portable_book_group_relative(
  group : PortableBookGroup,
  path : String,
) -> String? {
  if !portable_book_path_valid(path) {
    return None
  }
  if group.root == "" {
    return Some(path)
  }
  let prefix = group.root + "/"
  if path.has_prefix(prefix) {
    Some(path[prefix.length():].to_owned())
  } else {
    None
  }
}

///|
fn portable_book_group_count(state : PortableBookState) -> Int {
  let mut count = state.paths.length()
  for group in state.output_groups {
    count += group.files.length()
  }
  count
}

///|
fn portable_book_groups_valid(state : PortableBookState) -> Bool {
  state.output_groups.length() <= 16 &&
  portable_book_group_count(state) <= 128 &&
  state.output_groups.all(group => {
    !group.label.trim().is_empty() &&
    group.label.length() <= 120 &&
    !group.label.iter().any(c => c < ' ' || c == '\u007f') &&
    !group.files.is_empty() &&
    [group.preview_path, group.app_entrypoint].all(link => {
      match link {
        Some(path) => group.files.any(file => file.path == path)
        None => true
      }
    })
  })
}

///|
fn portable_book_group_wire(group : PortableBookGroup) -> Json {
  let value : Json = {
    "artifact_id": group.artifact_id,
    "label": group.label,
    "mime_type": if group.app_entrypoint is Some(_) {
      "text/html"
    } else {
      "application/octet-stream"
    },
    "files": group.files.to_json(),
  }
  guard value is Object(fields) else { return value }
  if group.preview_path is Some(path) {
    fields["preview_path"] = path.to_json()
  }
  if group.app_entrypoint is Some(path) {
    fields["app_entrypoint"] = path.to_json()
  }
  Json::object(fields)
}

///|
fn portable_book_grouped_body(
  library : String,
  id : String,
  version : String,
  paths : Array[String],
  groups : Array[PortableBookGroup],
  source : String?,
) -> Json {
  let body = match source {
    Some(source) =>
      portable_book_prepare_body(
        library,
        id,
        version,
        paths,
        accepted_human_result_base64=source,
      )
    None => portable_book_prepare_body(library, id, version, paths)
  }
  guard body is Object(fields) else { return body }
  fields["output_groups"] = groups.map(portable_book_group_wire).to_json()
  Json::object(fields)
}

///|
fn reduce_portable_group(
  state : PortableBookState,
  message : PortableGroupMsg,
) -> PortableBookState {
  if !state.active || portable_book_inputs_locked(state) {
    return state
  }
  match message {
    NameNewGroup(group_name) => { ..state, group_name, }
    SelectGroup(id) => {
      if !state.output_groups.any(group => group.artifact_id == id) {
        return state
      }
      { ..state, selected_group: id, }
    }
    AddGroup => {
      let label = state.group_name.trim().to_owned()
      if label == "" ||
        label.length() > 120 ||
        label.iter().any(c => c < ' ' || c == '\u007f') ||
        state.output_groups.length() >= 16 {
        return state
      }
      let id = "group-" + state.next_group_id.to_string()
      let groups = state.output_groups.copy()
      groups.push({
        artifact_id: id,
        label,
        root: state.directory,
        files: [],
        preview_path: None,
        app_entrypoint: None,
      })
      {
        ..portable_book_changed_inputs(state),
        output_groups: groups,
        selected_group: id,
        group_name: "",
        next_group_id: state.next_group_id + 1,
      }
    }
    RemoveGroup(id) => {
      if !state.output_groups.any(group => group.artifact_id == id) {
        return state
      }
      {
        ..portable_book_changed_inputs(state),
        output_groups: state.output_groups.filter(group => {
          group.artifact_id != id
        }),
        selected_group: if state.selected_group == id {
          ""
        } else {
          state.selected_group
        },
      }
    }
    _ => {
      let id = match message {
        RenameGroup(id, _)
        | RemoveGroupFile(id, _)
        | ChooseGroupPreview(id, _)
        | ChooseGroupEntrypoint(id, _) => id
        ToggleGroupFile(_) => state.selected_group
        _ => return state
      }
      guard state.output_groups.filter(group => group.artifact_id == id).get(0)
        is Some(group) else {
        return state
      }
      let next = match message {
        RenameGroup(_, label) => { ..group, label, }
        ToggleGroupFile(path) => {
          guard portable_book_group_relative(group, path) is Some(relative) &&
            state.entries.any(entry => {
              entry.workspace_id == state.workspace &&
              entry.path == path &&
              entry.kind != Directory &&
              entry.readable
            }) else {
            return state
          }
          if group.files.any(file => file.source_path == path) {
            portable_book_group_remove_file(group, path)
          } else {
            if portable_book_group_count(state) >= 128 {
              return state
            }
            if group.files.any(file => {
                file.path.to_lower() == relative.to_lower() ||
                file.path.to_lower().has_prefix(relative.to_lower() + "/") ||
                relative.to_lower().has_prefix(file.path.to_lower() + "/")
              }) {
              return {
                ..state,
                error: "This file conflicts with another path in the deliverable. Choose a distinct file layout.",
              }
            }
            let files = group.files.copy()
            files.push({ source_path: path, path: relative, })
            { ..group, files, }
          }
        }
        RemoveGroupFile(_, path) => portable_book_group_remove_file(group, path)
        ChooseGroupPreview(_, path) => {
          if !group.files.any(file => file.path == path) {
            return state
          }
          {
            ..group,
            preview_path: if group.preview_path == Some(path) {
              None
            } else {
              Some(path)
            },
          }
        }
        ChooseGroupEntrypoint(_, path) => {
          if !group.files.any(file => file.path == path) {
            return state
          }
          {
            ..group,
            app_entrypoint: if group.app_entrypoint == Some(path) {
              None
            } else {
              Some(path)
            },
          }
        }
        _ => return state
      }
      if next == group {
        return state
      }
      {
        ..portable_book_changed_inputs(state),
        output_groups: state.output_groups.map(group => {
          if group.artifact_id == id {
            next
          } else {
            group
          }
        }),
      }
    }
  }
}

///|
fn portable_book_group_remove_file(
  group : PortableBookGroup,
  source : String,
) -> PortableBookGroup {
  let files = group.files.filter(file => file.source_path != source)
  {
    ..group,
    files,
    preview_path: group.preview_path.filter(path => {
      files.any(file => file.path == path)
    }),
    app_entrypoint: group.app_entrypoint.filter(path => {
      files.any(file => file.path == path)
    }),
  }
}

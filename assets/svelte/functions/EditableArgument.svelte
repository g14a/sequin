<script lang="ts">
  import { EditorView, basicSetup } from "codemirror";
  import { EditorState } from "@codemirror/state";
  import { elixir } from "codemirror-lang-elixir";
  import { keymap } from "@codemirror/view";
  import { indentWithTab } from "@codemirror/commands";
  import { autocompletion } from "@codemirror/autocomplete";
  import { Pencil, Save, Ban } from "lucide-svelte";
  import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
  } from "$lib/components/ui/select";
  import type { FormData, FormErrors, TestMessage } from "./types";

  type ActionType = "insert" | "update" | "delete" | "read";
  type FieldType = "record" | "metadata" | "changes" | "action";

  export let form: FormData;
  export let formErrors: FormErrors;
  export let selectedMessage: TestMessage;

  let editorElement: HTMLElement;
  let editorView: EditorView | undefined;

  let isEditingField: boolean = false;
  let actionToSet: string;

  export let field: FieldType;

  const actionOptions: ActionType[] = ["insert", "update", "delete", "read"];

  function handleActionSelect(value: string) {
    if (field === "action" && actionOptions.includes(value as ActionType)) {
      actionToSet = `"${value}"` as ActionType;
    }
  }

  function cancelEdit() {
    if (field !== "action" && editorView) {
      // Reset the editor content to the original value
      editorView.dispatch({
        changes: {
          from: 0,
          to: editorView.state.doc.length,
          insert: selectedMessage[field],
        },
      });
    }
    isEditingField = false;
  }

  function saveEdit() {
    if (field === "action") {
      selectedMessage["action"] = actionToSet;
    } else {
      selectedMessage[field] = editorView.state.doc.toString();
    }
    form.modified_test_messages[selectedMessage.id] = selectedMessage;
    isEditingField = false;
  }

  // Add a function to create/update the editor view
  function updateMessageEditor(message: TestMessage) {
    // Only create editor for non-action fields
    if (field === "action") return;

    // Destroy existing editor if it exists
    if (editorView) {
      editorView.destroy();
      editorView = null;
    }

    const editorState = EditorState.create({
      doc: message[field],
      extensions: [
        keymap.of([
          indentWithTab,
          {
            key: "Cmd-Enter",
            run: () => {
              saveEdit();
              return true;
            },
          },
          {
            key: "Ctrl-Enter",
            run: () => {
              saveEdit();
              return true;
            },
          },
        ]),
        basicSetup,
        elixir(),
        autocompletion({ override: [] }),
      ],
    });

    editorView = new EditorView({
      state: editorState,
      parent: editorElement,
    });
  }

  $: updateMessageEditor(selectedMessage);
</script>

<div
  class="text-sm bg-slate-50 dark:bg-slate-800/50 p-3 rounded-md overflow-auto font-mono text-slate-700 dark:text-slate-300 select-text space-y-4 mb-3"
>
  <div class="font-semibold mb-1 flex w-full justify-between items-center">
    <span>{field}</span>
    {#if !isEditingField}
      <div>
        <button
          type="button"
          on:click={() => {
            isEditingField = true;
          }}
        >
          <Pencil
            class="h-4 w-4 ml-2 text-slate-500 hover:text-slate-700 cursor-pointer"
          />
        </button>
      </div>
    {:else}
      <div>
        <button
          type="button"
          on:click={() => {
            if (field === "action") {
              selectedMessage["action"] = actionToSet;
            } else {
              selectedMessage[field] = editorView.state.doc.toString();
            }
            form.modified_test_messages[selectedMessage.id] = selectedMessage;
            isEditingField = false;
          }}
        >
          <Save
            class="h-4 w-4 ml-2 text-slate-500 hover:text-slate-700 cursor-pointer"
          />
        </button>

        <button
          type="button"
          on:click={() => {
            cancelEdit();
          }}
        >
          <Ban
            class="h-4 w-4 ml-2 text-slate-500 hover:text-slate-700 cursor-pointer"
          />
        </button>
      </div>
    {/if}
  </div>
  {#if field === "action"}
    {#if isEditingField}
      <Select
        selected={{
          value: selectedMessage[field],
          label: selectedMessage[field],
        }}
        onSelectedChange={(event) => handleActionSelect(event.value)}
      >
        <SelectTrigger>
          <SelectValue placeholder="Select an action" />
        </SelectTrigger>
        <SelectContent>
          {#each actionOptions as option}
            <SelectItem value={option}>{option}</SelectItem>
          {/each}
        </SelectContent>
      </Select>
    {:else}
      <pre>{selectedMessage[field]}</pre>
    {/if}
  {:else}
    <div hidden={!isEditingField} bind:this={editorElement} />
    <pre hidden={isEditingField}>{selectedMessage[field]}</pre>
  {/if}
  {#if formErrors?.modified_test_messages?.[selectedMessage.id]?.[field]}
    <p class="text-sm text-red-500 dark:text-red-400">
      {formErrors.modified_test_messages[selectedMessage.id][field].type}: {formErrors
        .modified_test_messages[selectedMessage.id][field].info.description}
    </p>
  {/if}
</div>

<script lang="ts">
  import { Card, CardContent } from "$lib/components/ui/card";
  import { Button } from "$lib/components/ui/button";
  import * as Tooltip from "$lib/components/ui/tooltip";
  import {
    Database,
    HelpCircle,
    ExternalLink,
    BookOpen,
    Table2,
  } from "lucide-svelte";
  import LinkPushNavigate from "$lib/components/LinkPushNavigate.svelte";
  import type { Consumer, Source } from "./types";
  import type { Table } from "$lib/databases/types";

  export let consumer: Consumer;
  export let tables: Table[];

  function getSchemaStatus(source: Source): {
    type: string;
    description: string;
    items?: string[];
  } {
    if (source.include_schemas) {
      if (source.include_schemas.length === 1) {
        return {
          type: "including",
          description: `Including schema "${source.include_schemas[0]}"`,
        };
      } else {
        return {
          type: "including",
          description: `Including ${source.include_schemas.length} schemas`,
          items: source.include_schemas,
        };
      }
    }

    if (source.exclude_schemas) {
      if (source.exclude_schemas.length === 1) {
        return {
          type: "excluding",
          description: `Excluding schema "${source.exclude_schemas[0]}"`,
        };
      } else {
        return {
          type: "excluding",
          description: `Excluding ${source.exclude_schemas.length} schemas`,
          items: source.exclude_schemas,
        };
      }
    }

    return {
      type: "all",
      description: "All schemas",
    };
  }

  function getTableStatus(source: Source): {
    type: string;
    description: string;
    items?: string[];
  } {
    if (source.include_table_oids) {
      if (source.include_table_oids.length === 1) {
        const table = tables.find(
          (t) => t.oid === source.include_table_oids[0],
        );
        return {
          type: "including",
          description: `Including table "${table?.name}"`,
        };
      } else {
        return {
          type: "including",
          description: `Including ${source.include_table_oids.length} tables`,
          items: source.include_table_oids.map((oid) => {
            const table = tables.find((t) => t.oid === oid);
            return table?.name;
          }),
        };
      }
    }

    if (source.exclude_table_oids) {
      if (source.exclude_table_oids.length === 1) {
        const table = tables.find(
          (t) => t.oid === source.exclude_table_oids[0],
        );
        return {
          type: "excluding",
          description: `Excluding table "${table?.name}"`,
        };
      } else {
        return {
          type: "excluding",
          description: `Excluding ${source.exclude_table_oids.length} tables`,
          items: source.exclude_table_oids.map((oid) => {
            const table = tables.find((t) => t.oid === oid);
            return table?.name;
          }),
        };
      }
    }

    return {
      type: "all",
      description: "All tables",
    };
  }

  function isMultiTableSync(source: Source | null): boolean {
    if (!source) return false;

    // If syncing all tables and all schemas (no specific table filter)
    if (!source.include_table_oids && !source.exclude_table_oids) {
      return true;
    }

    // If syncing by schemas (multiple tables from schemas)
    if (source.include_schemas || source.exclude_schemas) {
      return true;
    }

    // If syncing multiple specific tables
    if (source.include_table_oids && source.include_table_oids.length > 1) {
      return true;
    }

    // If excluding specific tables (implies multiple remaining tables)
    if (source.exclude_table_oids) {
      return true;
    }

    return false;
  }
</script>

<Card>
  <CardContent class="p-6 space-y-6">
    <div class="flex justify-between items-center">
      <h2 class="text-lg font-semibold">Source</h2>
      <LinkPushNavigate href="/databases/{consumer.database.id}">
        <Button variant="outline" size="sm">
          <ExternalLink class="h-4 w-4 mr-2" />
          View Database
        </Button>
      </LinkPushNavigate>
    </div>
    <!-- Publication Section -->
    <div class="flex items-center space-x-2">
      <BookOpen class="h-5 w-5 text-gray-400" />
      <div class="font-medium">
        <p>
          Publication <span class="font-mono"
            >{consumer.database.publication_name}</span
          >
          in database
          <span class="font-mono">{consumer.database.name}</span>
        </p>
      </div>
    </div>

    <!-- Schema Section -->
    {@const schemaStatus = getSchemaStatus(consumer.source)}
    <div class="flex items-start space-x-2">
      <Database class="h-5 w-5 text-gray-400 mt-0.5" />
      <div class="flex-1">
        <p class="font-medium">{schemaStatus.description}</p>
        {#if schemaStatus.items}
          <div
            class="mt-2 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2"
          >
            {#each schemaStatus.items as item}
              <div class="bg-gray-50 px-3 py-2 rounded-md text-sm font-mono">
                {item}
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Table Section -->
    {@const tableStatus = getTableStatus(consumer.source)}
    <div class="flex items-start space-x-2">
      <Table2 class="h-5 w-5 text-gray-400 mt-0.5" />
      <div class="flex-1">
        <p class="font-medium">{tableStatus.description}</p>
        {#if tableStatus.items}
          <div
            class="mt-2 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2"
          >
            {#each tableStatus.items as item}
              <div class="bg-gray-50 px-3 py-2 rounded-md text-sm font-mono">
                {item}
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
    <div class="">
      <div class="flex items-center space-x-2">
        <h3 class="text-md font-semibold">Group columns</h3>
        <Tooltip.Root openDelay={200}>
          <Tooltip.Trigger>
            <HelpCircle
              class="inline-block h-2.5 w-2.5 text-gray-400 -mt-2 cursor-help"
            />
          </Tooltip.Trigger>
          <Tooltip.Content class="max-w-xs space-y-2">
            <p class="text-xs text-gray-500">
              {#if isMultiTableSync(consumer.source)}
                All tables are grouped by their primary key columns. Messages in
                a group are processed in FIFO order.
                <br />
                <br />
                Messages in different tables are processed in parallel.
              {:else}
                The columns of the stream table used to group messages. Messages
                in a group are processed in FIFO order.
                <br />
                <br />
                By default, the primary key columns of the stream table are used.
              {/if}
              <br />
              <br />
              See the
              <a
                class="text-blue-500 hover:underline"
                href="https://sequinstream.com/docs/reference/sinks/overview#message-grouping-and-ordering"
                target="_blank">docs</a
              >
              for more information.
            </p>
          </Tooltip.Content>
        </Tooltip.Root>
      </div>
      <p class="font-medium mt-2">Each table's primary key columns</p>
    </div>
  </CardContent>
</Card>

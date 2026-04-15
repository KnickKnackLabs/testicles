/** @jsxImportSource jsx-md */

import { readFileSync, readdirSync, existsSync } from "fs";
import { join, resolve } from "path";

import {
  Heading, Paragraph, CodeBlock, LineBreak, HR,
  Bold, Italic, Code, Link,
  Badge, Badges, Center, Section,
  Raw, HtmlLink, Sub,
} from "readme/src/components";

// ── Dynamic data ─────────────────────────────────────────────

const REPO_DIR = resolve(import.meta.dirname);
const TASK_DIR = join(REPO_DIR, ".mise/tasks");
const LIB_DIR = join(REPO_DIR, "lib");
const TEST_DIR = join(REPO_DIR, "test");

// ── Parse tasks ──────────────────────────────────────────────

interface Command {
  name: string;
  description: string;
  hidden: boolean;
}

function parseTask(filepath: string, name: string): Command {
  const src = readFileSync(filepath, "utf-8");
  const lines = src.split("\n");
  const desc =
    lines
      .find((l) => l.startsWith("#MISE description="))
      ?.match(/#MISE description="(.+)"/)?.[1] ?? "";
  const hidden = lines.some((l) => l.includes("#MISE hide=true"));
  return { name, description: desc, hidden };
}

function walkTasks(dir: string, prefix = ""): Command[] {
  const results: Command[] = [];
  if (!existsSync(dir)) return results;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".") || entry.name.startsWith("_")) continue;
    const fullPath = join(dir, entry.name);
    const taskName = prefix ? `${prefix}:${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      results.push(...walkTasks(fullPath, taskName));
    } else {
      results.push(parseTask(fullPath, taskName));
    }
  }
  return results;
}

const commands = walkTasks(TASK_DIR)
  .filter((c) => !c.hidden && c.name !== "test" && c.name !== "setup")
  .sort((a, b) => a.name.localeCompare(b.name));

// Categorize
const implemented = commands.filter((c) => {
  const src = readFileSync(join(TASK_DIR, c.name), "utf-8");
  return !src.includes("not implemented");
});
const stubs = commands.filter((c) => {
  const src = readFileSync(join(TASK_DIR, c.name), "utf-8");
  return src.includes("not implemented");
});

// Count tests
const testFiles = readdirSync(TEST_DIR).filter((f) => f.endsWith(".bats"));
const testSrc = testFiles
  .map((f) => readFileSync(join(TEST_DIR, f), "utf-8"))
  .join("\n");
const testCount = [...testSrc.matchAll(/@test "/g)].length;

// Count lib functions
const libSrc = readFileSync(join(LIB_DIR, "common.sh"), "utf-8");
const libFunctions = [...libSrc.matchAll(/^(\w+)\(\)/gm)].length;

// ── ASCII art ────────────────────────────────────────────────

const trustChain = [
  "        ┌───────────┐",
  "        │ Or Ricon  │   root of trust",
  "        └─────┬─────┘",
  "              │",
  "        ┌─────┴─────┐",
  "        │   Zeke    │   certifies ↓",
  "        └─────┬─────┘",
  "              │",
  "        ┌─────┴─────┐",
  "        │ Baby Joel │   certified ✓",
  "        └───────────┘",
].join("\n");

// ── README ───────────────────────────────────────────────────

const readme = (
  <>
    <Center>
      <Raw>{`<pre>\n` +
`        ╭─────╮\n` +
`      ╭─┴─╮ ╭─┴─╮\n` +
`      │   │ │   │\n` +
`      ╰───╯ ╰───╯\n` +
`\n` +
`  testicles inspect baby-joel@ricon.family\n` +
`\n` +
`  ✓ Certified by: Zeke\n` +
`  ✓ Certified by: Or Ricon\n` +
`</pre>\n\n`}</Raw>

      <Heading level={1}>testicles</Heading>

      <Paragraph>
        <Bold>GPG key management for humans and agents.</Bold>
      </Paragraph>

      <Paragraph>
        {"List, inspect, sign, verify, encrypt, decrypt — all through mise tasks."}
        {"\n"}
        {"Built around a query API that makes GPG's colon output usable."}
      </Paragraph>

      <Badges>
        <Badge label="lang" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tests" value={`${testCount} passing`} color="brightgreen" href="test/" />
        <Badge label="commands" value={`${implemented.length} implemented`} color="blue" />
        <Badge label="License" value="MIT" color="blue" />
      </Badges>
    </Center>

    <LineBreak />

    <Section title="Quick start">
      <CodeBlock lang="bash">{`# Install (--as keys gives you a sane CLI name)
shiv install testicles --as keys

# See what's on the keyring
keys list

# Inspect a key — algorithm, UIDs, subkeys, certifications
keys inspect baby-joel@ricon.family

# Sign a file, verify it
keys sign --file release.tar.gz --detach
keys verify --file release.tar.gz --sig release.tar.gz.asc

# Encrypt to a recipient, decrypt locally
keys encrypt --to zeke@ricon.family "deploy token: abc123"
keys decrypt --file message.asc`}</CodeBlock>
    </Section>

    <Section title="The trust chain">
      <Paragraph>
        {"GPG keys are only useful if you can verify who owns them. We use "}
        <Bold>key certifications</Bold>
        {" — one key signs another to say \"I've verified this person.\" "}
        {"The chain flows from Or (root) through agents:"}
      </Paragraph>

      <CodeBlock>{trustChain}</CodeBlock>

      <Paragraph>
        <Code>keys inspect</Code>
        {" shows certifications alongside key details — who vouches for this key, and when. "}
        <Code>keys list --secret</Code>
        {" shows which keys you can sign with. The rest of the commands are the operations that trust enables: signing, verifying, encrypting, decrypting."}
      </Paragraph>
    </Section>

    <Section title="What it wraps">
      <Paragraph>
        {"Every command calls "}
        <Code>gpg</Code>
        {" under the hood. The value isn't abstraction — it's "}
        <Bold>usability</Bold>
        {". GPG's native output is colon-delimited machine records. "}
        <Code>keys</Code>
        {" parses those into structured data ("}
        <Code>--json</Code>
        {") or formatted tables (default), handles key resolution by email/fingerprint/ID, and provides early error detection (e.g., refusing to sign with a key you don't own the secret for)."}
      </Paragraph>

      <Paragraph>
        {"The query API in "}
        <Code>lib/common.sh</Code>
        {` (${libFunctions} functions) does the heavy lifting: `}
        <Code>query_key_meta</Code>
        {", "}
        <Code>query_key_uids</Code>
        {", "}
        <Code>query_key_subkeys</Code>
        {", "}
        <Code>query_key_certifications</Code>
        {". Tasks are thin scripts that resolve args, call the query API, and format output."}
      </Paragraph>
    </Section>

    <Section title="Commands">
      {implemented.map((cmd) => (
        <>
          <Paragraph>
            <Code>{`testicles ${cmd.name}`}</Code>
            {` — ${cmd.description}`}
          </Paragraph>
        </>
      ))}

      {stubs.length > 0 && (
        <Paragraph>
          <Italic>{`Planned: ${stubs.map((c) => c.name).join(", ")} — stubs exist, implementation coming.`}</Italic>
        </Paragraph>
      )}
    </Section>

    <Section title="Library architecture">
      <CodeBlock>{`testicles/
├── lib/
│   └── common.sh          # Query API + formatting (${libFunctions} functions)
├── .mise/tasks/
│   ├── list               # Keyring listing with filters
│   ├── inspect            # Full key details + certifications
│   ├── export / import    # Key exchange (armored ASCII)
│   ├── sign / verify      # Content signing + verification
│   ├── encrypt / decrypt  # Recipient-based encryption
│   └── remove             # Key removal with confirmation
└── test/
    ├── test_helper.bash   # Isolated GPG homedir per test
    └── *.bats             # ${testFiles.length} suites, ${testCount} tests`}</CodeBlock>

      <Paragraph>
        {"Tests run against ephemeral GPG homedirs — each test gets a clean keyring with freshly generated keys. No interaction with the system keyring."}
      </Paragraph>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`git clone https://github.com/KnickKnackLabs/testicles.git
cd testicles && mise trust && mise install
mise run test`}</CodeBlock>

      <Paragraph>
        <Bold>{`${testCount} tests`}</Bold>
        {` across ${testFiles.length} suites — `}
        <Link href="https://github.com/bats-core/bats-core">BATS</Link>
        {" with isolated GPG homedirs per test case."}
      </Paragraph>
    </Section>

    <LineBreak />

    <Center>
      <HR />

      <Sub>
        {"Trust is a graph, not a list."}
        <Raw>{"<br />"}</Raw>{"\n"}
        <Raw>{"<br />"}</Raw>{"\n"}
        {"This README was generated from "}
        <HtmlLink href="https://github.com/KnickKnackLabs/readme">README.tsx</HtmlLink>
        {"."}
      </Sub>
    </Center>
  </>
);

console.log(readme);

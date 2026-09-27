# Pull request path (aegonex-done)

Read this at `aegonex-done` step 7.3, when the host refuses the push to `<Base>` as protected, and
at step 8. The rules of `../SKILL.md` hold here: its Language, one command per tool call and line,
git as `git -C "<absolute folder>"`, an exit code read from the tool result.

## Step 7.3: the push to <Base> is refused as protected

In order:
1. `git -C "<f>" push <remote> aegonex/<u>`, never `-u`; refused: stop and quote its `!` line.
2. `git -C "<main>" remote get-url <remote>`. Only when it prints `https://<host>/<owner>/<repo>`
   or `git@<host>:<owner>/<repo>`, each with or without `.git`: when `gh --version` works,
   `gh pr create --repo <owner>/<repo> --base <Base> --head aegonex/<u> --title "<u>: <name>" --body "<the checks that passed>"`;
   without gh, or when it fails, the link the push printed, else
   `https://<host>/<owner>/<repo>/compare/<Base>...aegonex/<u>`. Any other URL (a path,
   `file://`): no `gh pr create` and no compare link; `pull request <link>` in the reply after go
   becomes `` open a pull request for `aegonex/<u>` into `<Base>` on your host `` /
   `` เปิด pull request ของ `aegonex/<u>` เข้า `<Base>` ที่ host เอง ``. Never guess `<owner>/<repo>`.
3. No **Clean up**: the folder and branch stay until the pull request is merged. The reply after
   go is step 7's two lines, line 1 in its pull-request form (step 6's ignored files after the folder).

## Step 8: after a pull request

Step 1 has run in full first. Two cases:

**Waiting** (closed, online, and the user has not said it is merged; printed only then): title
`**<u> waits for its pull request.**` / `**<u> รอ merge pull request**`, the row `Pull request` /
`pull request` with `aegonex/<u> into <Base>`, the action line `**When it is merged:** update
<Base> here, remove .worktrees/<u> and aegonex/<u>` / `**เมื่อ merge แล้ว:** อัปเดต <Base> ในเครื่อง
ลบ .worktrees/<u> และ aegonex/<u>`, the `Goes with the folder` row of step 6, and the question
`Merged? Remove now?` / `merge แล้วใช่ไหม ลบเลยไหม?` with `Not yet` / `ยังไม่ merge` first, then
`go`, or the last line `Reply **go** once it is merged, to remove the folder and branch.` /
`พิมพ์ **go** เมื่อ merge แล้ว เพื่อลบโฟลเดอร์และ branch`. A go to it is the user saying it is merged.

**Merged** (the user says so): first compare, before any fetch,
`git -C "<main>" rev-parse aegonex/<u>` with `git -C "<main>" rev-parse --verify -q <remote>/aegonex/<u>`:
- the second prints nothing: `git -C "<main>" fetch <remote> <Base>`; it is merged when
  `git -C "<main>" merge-base --is-ancestor aegonex/<u> <remote>/<Base>` exits 0, else stop,
  `the online copy of aegonex/<u> is gone`; if the pull request is merged, by hand:
  `git -C "<main>" worktree remove "<f>"`, then `git -C "<main>" branch -D aegonex/<u>`;
- different: stop, `aegonex/<u> has commits the pull request lacks`, first step by hand:
  `git -C "<f>" push <remote> aegonex/<u>`;
- equal (nothing is unpushed): `git -C "<main>" fetch <remote> <Base>`.

Then, equal or merged:
- the unit is closed: its close brief's go already named removing `.worktrees/<u>` and
  `aegonex/<u>`, so **Clean up** (step 7.4) runs at once from its step 2, after its `cd`, with
  `branch -D`; no second question. The reply is step 7's two lines, line 2 its `Next` line, line 1
  `` `a1b2c3d` · merged into `main` · `.worktrees/m2` removed `` /
  `` `a1b2c3d` · merge เข้า `main` แล้ว · ลบ `.worktrees/m2` แล้ว ``;
- not closed (landed unfinished by `aegonex-exit`): ask `Remove .worktrees/<u> now?` /
  `ลบ .worktrees/<u> เลยไหม?` with `Keep` / `เก็บไว้` first and `Remove` / `ลบ`, or end with
  `Reply **remove** to remove .worktrees/<u>, or anything else to keep it.` /
  `พิมพ์ **remove** เพื่อลบ .worktrees/<u> หรือพิมพ์อย่างอื่นเพื่อเก็บไว้`, naming after the folder the
  ignored files of step 6 (`(with .env)` / `(พร้อม .env)`). No answer is Keep; Remove runs
  **Clean up** from its step 2, after its `cd`, with `branch -D`.

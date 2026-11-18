# Research group editing and Overleaf workflow

The authoritative manuscript is `paper/latex/` in
<https://github.com/Markvsid/EAT_FPGA>. Track the `.tex`, `.bib`, figure and small
evidence files in Git. Do not commit `.aux`, `.bbl`, `.log`, `.synctex.gz`, build
PDFs or generated ZIPs. CI artifacts provide compiled reading/upload copies.

## Edit through Git

1. Obtain repository write access from its owner, or use a fork and pull request.
   No collaborator permissions are changed by this scaffold.
2. Pull the latest code and create a short-lived branch before writing:

   ```sh
   git switch main
   git pull --ff-only origin main
   git switch -c paper/describe-your-change
   ```

3. Coordinate section ownership with the group. Edit one sentence per source
   line where practical to keep reviews and merges readable. Use `\label` and
   `\ref` for cross-references, and `\cite{key}` with `references.bib` for citations.
4. Run the source check and build. Inspect the PDF, references and tables.
5. Commit and push the specific source changes and open a pull request:

   ```sh
   git add paper/latex/sections/01_introduction.tex
   git commit -m "Draft paper introduction"
   git push -u origin paper/describe-your-change
   ```

6. Review scientific claims, numerical provenance, and the compiled artifact
   before merging. Resolve conflicting text rather than force-pushing over peers.

## Create the Overleaf project

1. Run `python3 paper/latex/scripts/package_overleaf.py`, or download the paper
   ZIP from the LaTeX workflow artifact on GitHub.
2. In Overleaf choose **New project → Existing project (.zip)** and upload
   `EAT_FPGA_Lite_TRETS_Overleaf.zip`.
3. Set the main document to `main.tex`, select **XeLaTeX**, choose a compatible
   TeX Live version, and recompile. The current reference uses TeX Live 2026;
   record whichever release the group actually uses.
4. The project owner uses **Share** to invite the agreed group members with
   Editor access, subject to the account's collaborator allowance. Authorship
   order and access permissions are separate decisions.

[Overleaf upload instructions](https://docs.overleaf.com/managing-projects-and-files/uploading-a-project)
and [sharing instructions](https://docs.overleaf.com/collaborating/sharing-a-project).

## Keep ZIP-based Overleaf edits in version control

Uploading a ZIP does **not** connect the project to GitHub. Assign one person to
coordinate synchronization and agree when people may edit each side:

1. Start an Overleaf editing session from the latest accepted Git snapshot.
2. Finish/coordinate the session, then download the Overleaf source ZIP.
3. Unzip it to a temporary directory. Compare it with `paper/latex/` on a new Git
   branch; copy only reviewed text/bibliography/figure changes, not build files.
   Do not overwrite the repository or frozen evidence snapshots wholesale.
4. Run checks/build, commit with the contributors identified in the message or
   agreed coauthor trailers, and review/merge the pull request.
5. Update the shared Overleaf sources from that merged version before the next
   session. Keep Overleaf comments resolved or recorded before replacing files.

Git commits preserve the research group's accepted history even when several
Overleaf edits are combined into one export.

## Optional native GitHub synchronization

Overleaf documents native GitHub sync as a premium/account-dependent feature,
initialized by the project owner. It is an explicit push/pull workflow, not an
automatic background sync. An existing ZIP-created project cannot simply be
attached to an existing GitHub repository through that feature.

Use a dedicated paper-only repository if the group enables native integration;
do not import the full research repository with its large artifacts and thousands
of files. Define one maintainer and a documented round trip back to this
canonical `paper/latex/` tree before introducing a second remote. No separate
paper repository or native integration has been created here.

[Current Overleaf GitHub synchronization documentation](https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/github-synchronization).

# ---------- CONFIG ----------------------------------------------------------
TEAM="Architecture Team"
ITER_ROOT="Youlend-Infrastructure"          # root node shown in Boards → Project configuration
NEXT_SPRINT=18                              # create 18, 19, 20… etc.
COUNT=5                                     # how many new sprints
CADENCE=14                                  # days per sprint
START="2025-09-03"                          # first sprint start date (yyyy-mm-dd)
# ----------------------------------------------------------------------------

for ((i=0;i<$COUNT;i++)); do
  n=$((NEXT_SPRINT+i))
  sd=$(date -I -d "$START +$((i*CADENCE)) days")
  ed=$(date -I -d "$sd +$((CADENCE-1)) days")

  NAME="Architecture Sprint $n"
  PATH="\\$ITER_ROOT\\$NAME"

  echo "🌀  Creating $NAME  $sd → $ed"

  # 1) Project-level iteration
  az boards iteration project create           \
        --name "$NAME"                         \
        --path "\\$ITER_ROOT"                  \
        --start-date "$sd" --finish-date "$ed"

  # 2) Add to team & set as active
  az boards iteration team add                 \
        --team "$TEAM" --path "$PATH"
  az boards iteration team set                 \
        --team "$TEAM" --path "$PATH"

  # 3) Seed two default User Stories
  for T in "BAU Sprint $n" "Trainings Sprint $n"; do
    az boards work-item create \
        --type "User Story"    \
        --title "$T"           \
        --iteration-path "$PATH" \
        --description "Auto-seeded by sprint bootstrap script"
  done
done
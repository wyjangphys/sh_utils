. ${PWD}/progress_bar.sh

progress_init 50

for i in $(seq 0 50); do
  progress_bar "$i" 50
  # == do your work here ==
  sleep 0.1
  # ======================
done
oc adm new-project openshift-local-storage

oc annotate namespace openshift-local-storage openshift.io/node-selector=''

oc annotate namespace openshift-local-storage workload.openshift.io/allowed='management'

oc apply -f openshift-local-storage.yaml

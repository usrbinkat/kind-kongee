#!/usr/bin/env bash

# Sample: Create an admin token 
#   http -v ${API_HOST_URL}:${API_PORT}/rbac/users name=super-admin user_token=kong 
# Start kong with KONG_ENFORCE_RBAC=on KONG_ADMIN_GUI_AUTH=basic-auth KONG_ADMIN_GUI_SESSION_CONF='{"secret":"secret","storage":"kong","cookie_secure":false}' 
#
# Hints:
#   Workspace Name       : ${WS_PREFIX}_${w}
#   Adumi User Name      : admin_${a}_${WS_PREFIX}_${w}
#   Adumi User Password  : ${ADMINS_PASSWORD}
#   Consumer Name        : $consumer${r}
#   Consumer Key-Auth Key: ${APIKEY_PREFIX}_s${s}_r${r} 

VERSION=0.4

# Variables
API_HOST_URL="http://localhost"
API_PORT=18001
ADMIN_TOKEN="kong"
ADMINS_PASSWORD="password"
WS_PREFIX="ws" 
NUM_WS=36 # The number of workspaces
NUM_USERS_PER_WS=1
NUM_SERVICES_PER_WS=1
NUM_ROUTES_PER_SERVICE=1
#ENABLE_SVC_ROUTE=( 01 ) # Condition which workspace to create services/routes
#ENABLE_SVC_ROUTE=( $( seq -s " " -w 1  10 ) )   # Condition which workspace to create services/routes
ENABLE_SVC_ROUTE=( 01 03 05 07 09 10 12 14 16 18 21 23 25 27 29 ) # Condition which workspace to create services/routes
PLUGIN_KEYAUTH_ENABLED=true #  Per route: "true" or anything else
CREATE_CONSUMER=true        #  Per route: "true" or anything else
APIKEY_PREFIX="apikey"
ENABLE_ADMIN_ROLE_IN_DEFAULT_WS=( 01 02 03 04 ) # Only enable default admin to certain workspace admins users

for w in $(seq -f %02g 1 ${NUM_WS})
do
  # Create a workspace
  http -v ${API_HOST_URL}:${API_PORT}/workspaces name=${WS_PREFIX}_${w} kong-admin-token:${ADMIN_TOKEN}

  # Create service/routes only if the workspace number is in ENABLE_SVC_ROUTE array
  if [[ "${ENABLE_SVC_ROUTE[*]}" =~ "${w}" ]]; then
    for s in $(seq -f %02g 1 ${NUM_SERVICES_PER_WS} )
    do
      # Create a service
      http POST ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/services name=svc${s} url="http://httpbin.org" kong-admin-token:${ADMIN_TOKEN}

      # Create routes
      for r in $(seq -f %02g 1 ${NUM_ROUTES_PER_SERVICE} )
      do
        # Note: Avoid route collision between workspaces
        curl -sX POST ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/services/svc${s}/routes -d name=s${s}_r${r} -d paths="/ws${w}_s${s}_r${r}" -H kong-admin-token:${ADMIN_TOKEN} ; echo ""

        # Enable key-auth plugin
        if [ ${PLUGIN_KEYAUTH_ENABLED} == true ]; then
          curl -sX POST ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/routes/s${s}_r${r}/plugins -d name=key-auth -H kong-admin-token:${ADMIN_TOKEN} ; echo ""
        fi

        # Create Consumer: Same number as route
        if [ ${CREATE_CONSUMER} == true ]; then
          curl -sX POST ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/consumers -d username=consumer${r} -H kong-admin-token:${ADMIN_TOKEN} ; echo ""
          if [ ${PLUGIN_KEYAUTH_ENABLED} == true ]; then
            curl -sX POST ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/consumers/consumer${r}/key-auth -d key=${APIKEY_PREFIX}_s${s}_r${r} -H kong-admin-token:${ADMIN_TOKEN} ; echo ""
          fi
        fi

      done
    done
  fi


  # Create workspace RBAC roles
  # shellcheck disable=SC2153
  http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles comment="Full endpoints access" name="workspace-super-admin" kong-admin-token:${ADMIN_TOKEN}
  http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles comment="Full endpoints access except RBAC Admin API" name="workspace-admin" kong-admin-token:${ADMIN_TOKEN}
  http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles comment="Read access to all endpoints" name="workspace-read-only" kong-admin-token:${ADMIN_TOKEN}
  http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles comment="Full access to Dev Portal related endpoints in the workspace" name="workspace-portal-admin" kong-admin-token:${ADMIN_TOKEN}

  # Create permissions for what each role can do with endpoints within workspace
  ## read-only can only read all endpoints within the workspace
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-read-only/endpoints workspace="$WS_PREFIX"_"$w" actions=read endpoint=* negative=false kong-admin-token:${ADMIN_TOKEN} -f
  ## super-admin can do all crud on all endpoints within the workspace
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-super-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=delete,create,update,read endpoint=* negative=false kong-admin-token:${ADMIN_TOKEN} -f
  ## workspace-admin can perform crud on all endpoints within workspace except for rbac
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=delete,create,update,read endpoint=* negative=false kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=delete,create,update,read endpoint=rbac/*/*/*/*/* negative=true kong-admin-token:${ADMIN_TOKEN} -f

  # Read seems to need some special treatment
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=read endpoint=rbac/* negative=true kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=read endpoint=rbac/*/* negative=true kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=read endpoint=rbac/*/*/* negative=true kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/rbac/roles/workspace-admin/endpoints workspace="$WS_PREFIX"_"$w" actions=read endpoint=rbac/*/*/*/* negative=true kong-admin-token:${ADMIN_TOKEN} -f

  # workspace-portal-admin endpoints permissions
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=/developers negative=false   kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=/developers/* negative=false kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=/files negative=false        kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=/files/* negative=false      kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=/kong negative=false         kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=rbac/* negative=true         kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=rbac/*/* negative=true       kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=rbac/*/*/* negative=true     kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=rbac/*/*/*/* negative=true   kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="delete,create,update,read" endpoint=rbac/*/*/*/*/* negative=true kong-admin-token:${ADMIN_TOKEN} -f
  http ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${w}/rbac/roles/workspace-portal-admin/endpoints workspace=${WS_PREFIX}_${w} actions="update,read"               endpoint=workspaces/${WS_PREFIX}_${w} negative=false kong-admin-token:${ADMIN_TOKEN} -f

  # Invite admins
  for a in $(seq -f %02g 1 ${NUM_USERS_PER_WS})
  do
    http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/admins username=admin_"${a}"_"$WS_PREFIX"_"$w" email=admin_"${a}"_"$WS_PREFIX"_"${w}"@konghq.local rbac_token_enabled=true kong-admin-token:${ADMIN_TOKEN} -f
    http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/admins/admin_"${a}"_"$WS_PREFIX"_"$w"/roles roles=workspace-admin kong-admin-token:${ADMIN_TOKEN}

    reg_token=$(http ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/admins/admin_"${a}"_"$WS_PREFIX"_"$w"\?generate_register_url=true kong-admin-token:${ADMIN_TOKEN} | jq -r .token)
    #echo "RBAC User Token: ${reg_token}"
    http -v ${API_HOST_URL}:${API_PORT}/"$WS_PREFIX"_"$w"/admins/register token="${reg_token}" username=admin_"${a}"_"$WS_PREFIX"_"$w" email=admin_"${a}"_"$WS_PREFIX"_"${w}"@konghq.local password=${ADMINS_PASSWORD} kong-admin-token:${ADMIN_TOKEN}

    # This is to make an Admins user to authentiated at least once
    http -v ${API_HOST_URL}:${API_PORT}/auth kong-admin-user:admin_${a}_${WS_PREFIX}_${w} -a  admin_${a}_${WS_PREFIX}_${w}:${ADMINS_PASSWORD} --session=./session
    http -v ${API_HOST_URL}:${API_PORT}/routes kong-admin-user:admin_${a}_${WS_PREFIX}_${w} -a  admin_${a}_${WS_PREFIX}_${w}:${ADMINS_PASSWORD} --session=./session

  done
done

# Assign workspace-read-only role
for ws in $(seq -f %02g 1 ${NUM_WS} ) 
do 
  for admin_id in $(seq -f %02g 1 ${NUM_USERS_PER_WS})
  do
    for ws_id in $(seq -f %02g 1 ${NUM_WS})
    do 
      if [ ${ws} -ne ${ws_id}  ]
      then
        http -v ${API_HOST_URL}:${API_PORT}/${WS_PREFIX}_${ws}/admins/admin_${admin_id}_${WS_PREFIX}_${ws_id}/roles roles=workspace-read-only kong-admin-token:${ADMIN_TOKEN}
      fi
    done
  done
done

# Assign default admins role to only certain workspace admins
for ws in $(seq -f %02g 1 ${NUM_WS} ) 
do 
  if [[ "${ENABLE_ADMIN_ROLE_IN_DEFAULT_WS[*]}" =~ "${ws}" ]]; then
    for admin_id in $(seq -f %02g 1 ${NUM_USERS_PER_WS})
    do
      http -v ${API_HOST_URL}:${API_PORT}/default/admins/admin_${admin_id}_${WS_PREFIX}_${ws}/roles roles=admin kong-admin-token:${ADMIN_TOKEN}
    done
  fi
done

#!/usr/bin/bash


# This script is used to renew the certificates on your AWS loadbalancers using letsencrypt. Since letsencrypt
# certificates are ONLY valid for 3 months. The certificates needs to be renewed using automation. This script takes care of generating
# and updating the certificates on the AWS loadbalancers before they expire.

# References:
#  http://marketing.intracto.com/renew-https-certificate-on-amazon-cloudfront
#  https://vincent.composieux.fr/article/install-configure-and-automatically-renew-let-s-encrypt-ssl-certificate
#  https://github.com/alex/letsencrypt-aws


REGION="us-west-2"
NOTIFY_DISTRO="sagar@nirmata.com"

sendemail() {

         body="Something went wrong with certificate renewal...!"
         mailx -s "Alert: Letsencrypt Certificate renewal has failed for \"$1\" domain. Please check the log and take appropriate actions!" $NOTIFY_DISTRO <<< `echo $body`

}

folder() {
        CHECK_WC=$(echo $1 | grep "*.")
        if [[ ! -z $CHECK_WC ]]; then
                TEMP=${1:2}
                FOLDER=$(ls -lrt /etc/letsencrypt/live | awk '{ print $NF }' | grep "^$TEMP" | tail -1)
        else
                FOLDER=$(ls -lrt /etc/letsencrypt/live | grep $1 | tail -1 | awk '{ print $NF}')
        fi
}


update-certs(){
        LE_CERT_CREATE_DATE=$(date +%Y-%m-%d)
        certbot certonly --dns-route53 --dns-route53-propagation-seconds 60 -d $1 -d nirmata.io --agree-tos --no-bootstrap --preferred-challenges dns-01
        if [[ $? = 0 ]]; then

                # FOLDER=$(ls -1 /etc/letsencrypt/live | grep $1)
                folder $1
                echo "Folder name is: $FOLDER"
                aws acm import-certificate --region $REGION --profile "prod" --certificate fileb:///etc/letsencrypt/live/$FOLDER/cert.pem --certificate-chain fileb:///etc/letsencrypt/live/$FOLDER/chain.pem --private-key fileb:///etc/letsencrypt/live/$FOLDER/privkey.pem
                aws elbv2 describe-load-balancers --region $REGION --profile "prod" | jq '.LoadBalancers[].LoadBalancerName' | sed "s/\"//g" > lblist_$REGION.txt


                for lb in $(cat lblist_$REGION.txt |  grep prod-2021)
                do
                        # get loadbalancer arn based on the loadbalancer name
                        LB_ARN=$(aws elbv2 describe-load-balancers --names $lb --region $REGION --profile "prod"| jq '[.LoadBalancers | .[] | .LoadBalancerArn]' | jq .[0] | sed "s/\"//g")

                        # get listener arn based on loadbalancer arn
                        LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --region $REGION --profile "prod" --query 'Listeners[?Protocol==`HTTPS`].ListenerArn | [0]' | sed "s/\"//g")

                        # get certificate arn based on listener arn
                        CERT_ARN=$(aws elbv2 describe-listener-certificates --listener-arn $LISTENER_ARN --region $REGION --profile "prod" --query 'Certificates[?IsDefault==`true`].CertificateArn' --output yaml | awk '{ print $NF}')

                        # get domain name or subject CN name based on certificate arn
                        DOMAIN_NAME=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region $REGION --profile "prod" | jq '.Certificate.Subject' | sed "s/\"//g" | cut -d "=" -f2)

                        if [[ $1 = $DOMAIN_NAME ]]; then
                                aws acm list-certificates --region $REGION --profile "prod" --query 'CertificateSummaryList[].CertificateArn' --output yaml | awk '{print $NF}' > acm-certificates.txt
                                for cert in $(cat acm-certificates.txt)
                                do
                                        CREATEDAT=$(aws acm describe-certificate --certificate-arn $cert --region $REGION --profile "prod" | jq '.Certificate.CreatedAt' |sed "s/\"//g" | cut -d "T" -f1)
                                        CERT_DOMAIN_NAME=$(aws acm describe-certificate --certificate-arn $cert --region $REGION --profile "prod" | jq '.Certificate.Subject' | sed "s/\"//g" | cut -d "=" -f2)

                                        if [[ $LE_CERT_CREATE_DATE = $CREATEDAT ]] && [[ $DOMAIN_NAME = $1 ]]; then

                                                aws elbv2 modify-listener --listener-arn $LISTENER_ARN --certificates CertificateArn=$cert --region $REGION --profile "prod"
                                                sleep 1m
                                                NEW_CERT_ARN=$(aws elbv2 describe-listener-certificates --listener-arn $LISTENER_ARN --region $REGION --profile "prod" --query 'Certificates[?IsDefault==`true`].CertificateArn' --output text)
                                                aws elbv2 add-listener-certificates --listener-arn $LISTENER_ARN --certificates CertificateArn=$NEW_CERT_ARN --region $REGION --profile "prod"

                                        fi
                                done
                        fi
                done
        else
                #echo -e "Something went wrong when generating the certicate. Please check the letsencrypt certicates"
                sendemail

        fi
}

#### main

EXP_LIMIT=30

ALL_DOMAINS="*.nirmata.io"

for LE_DOMAIN in $ALL_DOMAINS
do
        folder $LE_DOMAIN
        CERT_FILE="/etc/letsencrypt/live/$FOLDER/fullchain.pem"

        if [ ! -f $CERT_FILE ]; then
                update-certs $LE_DOMAIN
        else
                DATE_NOW=$(date -d "now" +%s)
                EXP_DATE=$(date -d "`openssl x509 -in $CERT_FILE -text -noout | grep "Not After" | cut -c 25-`" +%s)
                EXP_DAYS=$(echo \( $EXP_DATE - $DATE_NOW \) / 86400 |bc)
                echo "Checking expiration date for $LE_DOMAIN..."
                if [[ $EXP_DAYS -lt $EXP_LIMIT ]]; then
                        if [[ $(date +%u) = 6 ]]; then
                                echo "Renewing certificates for $LE_DOMAIN..."
                                update-certs $LE_DOMAIN
                        else
                                echo "Today is not saturday!"
                        fi
                else
                        echo "Certificates are upto date!"
                fi
        fi
done
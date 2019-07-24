FROM ibmcom/ace:11.0.0.4
ENV BAR1=apis_api.bar
COPY $BAR1 /home/aceuser/
RUN bash -c 'mqsicreateworkdir /home/aceuser/ace-server'
RUN bash -c 'mqsibar -w /home/aceuser/ace-server -a /home/aceuser/$BAR1 -c'
